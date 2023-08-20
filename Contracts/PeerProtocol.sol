// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract PeerProtocol is Initializable, Ownable{ 

    constructor() initializer  {

        principalAmount = 0;
        loanRate = 0;
        loanPeriod = 0;

    }

    mapping ( address => uint ) public balances;
    mapping ( address => uint ) public tokenId;

    uint tenthK = 10000;
    uint dayConvention = 12;

    address public borrowerAdd;
    uint public principalLimit;
    uint public originationRate;
    uint public peerRate;
    uint public loanRate;
    uint public loanPeriod;

    uint public principalAmount;
    uint public principalPayable;
    uint public totalPayable;
    uint public feePayable; 

    uint public monthlyRepayment;

    uint private currentTid = 0;

    bool public loanDefault;
    bool public loanStatus;

    event createLoan( address borrower, uint amount, uint fee, uint rate, uint period);
    event Transfer( address _from, address _to, uint amount);

    function newLoan( address borrower, uint amount, uint rate, uint period, uint peerIRate, uint originateRate ) public onlyOwner {

        require(rate >= 10, "The lending rate must be at least 10 Basis Point (0.1%)");
        require(peerIRate < rate && peerIRate >= 40, "Fee Payable for PeerRate must be less than lending rate offered and at least 40 BP (0.4%)");
        require(originateRate >= 50, "Origination fee must be at least 50 BP (0.5%)");
        require(period >= 1, "The loan period must be at least 1 Month");

        borrowerAdd = borrower;
        principalLimit = amount;
        loanRate = rate;
        originationRate = originateRate;
        peerRate = peerIRate;
        loanPeriod = period;

        loanDefault = false;
        loanStatus = true;

        emit createLoan(borrower, principalLimit, feePayable, rate, period);
    }

    function joinLoan( uint amount ) public  {
        require(loanStatus, "The loan is not created");
        require(amount >= 0, " Please invest in the loan more than 1");
        require(amount + principalAmount <= principalLimit, "You have exceeded the maximum principal of the loan");
        
        IERC20 token = IERC20(msg.sender);
        require(token.balanceOf(msg.sender) >= amount, "You have insufficient amount");

        principalAmount += amount;

        uint originationNominal = ( amount * originationRate ) / tenthK;
        uint originationFee = ( originationNominal * ( 10000 + ( loanRate*loanPeriod ) / dayConvention )) / tenthK;
        uint peerFee =  ( amount * ((peerRate*loanPeriod)/dayConvention)) / tenthK;
        feePayable += peerFee + originationFee;

        uint principalInt = ( amount * ( 10000 + (( loanRate-peerRate ) * loanPeriod )/dayConvention))/ tenthK;
        principalPayable += principalInt;

        totalPayable = feePayable + principalPayable;
        monthlyRepayment += totalPayable / loanPeriod;
        currentTid += 1;

        balances[msg.sender] += amount;
        tokenId[msg.sender] = currentTid;

        token.transfer(address(this), amount);
        
        _transfer(msg.sender, borrowerAdd, amount);

        emit Transfer(address(0), msg.sender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function repayment( address borrower, uint amount ) public {
        require( amount >= ( monthlyRepayment * 8000 ) / 10000, "Please pay at least 80% of the required amount");
        totalPayable -= amount;
        loanPeriod -= 1;

        balances[borrower] += amount;

    }
}

