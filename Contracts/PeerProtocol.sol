// SPDX-License-Identifier: MIT 
// Version: 0.0.0
pragma solidity >=0.7.3 <0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";


interface TERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract PeerProtocol is Initializable, Ownable, ERC1155 {

    mapping ( uint => address ) public tokenId;
    mapping ( address => uint ) public balances;
    mapping ( address => uint ) public repaymentBalance;
    mapping ( address => uint ) public repayment;
    mapping ( address => uint ) public principalBalance;

    uint private tenthK = 10000;
    uint private dayConvention = 360;
    uint private scconversion = 1000000000000000000;

    TERC20 private token = TERC20(address(0x1BD7B233B054AD4D1FBb767eEa628f28fdE314c6)); //Polygon
    address public borrowerAdd;
    uint public principalLimit;
    uint public drawnBalance;
    uint public originationRate;
    uint public peerRate;
    uint public loanRate;
    uint public loanPeriod;

    uint public principalAmount;
    uint public principalPayable;
    uint public totalPayable;
    uint public feePayable; 

    uint public monthlyFee;
    uint public monthlyRepayment;

    uint public currentTid = 0;

    bool public loanDefault;
    bool public loanStatus;
    uint public originationNominal;

    uint public startDate;
    uint public endDate;


    event createLoan( address borrower, uint amount, uint rate, uint period, uint timestamp, string method );
    event Joined( address _from, address _to, uint amount, uint timestamp, string method );
    event Withdrawal(address _to, uint amount, uint timestamp, string method);
    event drawnDown( address borrower, uint amount, uint timestamp, string method );
    event repayLoan( address borrower, uint amount, uint timestamp, string method );
    event Transfer(address lender, address borrower, uint timestamp, uint amount, string method);

    constructor(
        string memory _uri, 
        address borrower, 
        uint amount, 
        uint rate, 
        uint period, 
        uint peerIRate, 
        uint originateRate,
        uint startingDate,
        uint endingDate
        ) initializer ERC1155(_uri) {
        principalAmount = 0;
        loanRate = 0;
        loanPeriod = 0; // This will only accept in days factor
        setURI(_uri);
        newLoan(borrower, amount, rate, period, peerIRate, originateRate, startingDate, endingDate);
    }

    function newLoan( 
        address borrower, 
        uint amount, 
        uint rate, 
        uint period, 
        uint peerIRate, 
        uint originateRate,
        uint startingDate,
        uint endingDate
        ) private onlyOwner {

        require(rate >= 10, "The lending rate must be at least 10 Basis Point (0.1%)");
        require(peerIRate < rate && peerIRate >= 40, "Fee Payable for PeerRate must be less than lending rate offered and at least 40 BP (0.4%)");
        require(originateRate >= 50, "Origination fee must be at least 50 BP (0.5%)");
        require(period >= 1, "The loan period must be at least 1 Month");
        require(startingDate < endingDate, "loan period issue, start date is later than end date");
        require(block.timestamp < startingDate && block.timestamp < endingDate, "Contract creation date is later than loan start date");
        

        borrowerAdd = borrower;
        principalLimit = amount;
        loanRate = rate;
        originationRate = originateRate;
        peerRate = peerIRate;
        loanPeriod = period;
        startDate = startingDate;  // Set start date
        endDate = endingDate;  // Set end date 

        loanDefault = false;
        loanStatus = true;

        emit createLoan(borrower, principalLimit, rate, period, block.timestamp, "Loan Created");
    }

    function joinLoan( uint amount ) public {
        require(loanStatus, "The loan is not created");
        require(amount >= 1, " Please invest in the loan more than 1");
        require(amount + principalAmount <= principalLimit, "You have exceeded the maximum principal of the loan");
        require((token.balanceOf(msg.sender) / scconversion) >= amount, "Insufficient amount");
        require(block.timestamp < startDate, "Loan Participation is after start date");
        
        principalAmount += amount;

        originationNominal = ( amount * originationRate ) / tenthK;
        uint originationFee = ( originationNominal * ( 10000 + ( loanRate*loanPeriod ) / dayConvention )) / tenthK;
        uint peerFee =  ( amount * ((peerRate*loanPeriod)/dayConvention)) / tenthK;
        feePayable += peerFee + originationFee;

        uint principalInt = ( amount * ( 10000 + (( loanRate-peerRate ) * loanPeriod )/dayConvention))/ tenthK;
        principalPayable += principalInt;

        totalPayable = feePayable + principalPayable;
        monthlyRepayment = totalPayable / loanPeriod;
        currentTid += 1;

        tokenId[currentTid] = msg.sender;
        balances[borrowerAdd] += amount;
        repaymentBalance[msg.sender] += principalInt;
        repayment[msg.sender] = principalInt / loanPeriod;
        principalBalance[msg.sender] += amount;

        monthlyFee = feePayable / loanPeriod;

        token.transferFrom(msg.sender, address(this), amount * scconversion); 
        
        emit Joined( msg.sender, address(this), amount, block.timestamp,  "Joined Loan");
    }

    function loanDrawn( uint amount ) public onlyOwner {
        require( loanStatus, "The loan is active");
        require( block.timestamp >= startDate, "Loan cannot be drawn before start date");  // Enforce start date
        require( amount >= 1, "Please withdraw amount more than 1");
        require( balances[msg.sender] <= amount , "You have entered an amount more than your balance");
        require( (token.balanceOf(address(this)) / scconversion ) >= amount, "Insufficient withdrawal amount");
        require( ((principalAmount * tenthK ) / principalLimit ) >= 8000, "Loan participation is less than 80%");

        drawnBalance += amount;
        token.transfer(msg.sender, amount * scconversion);

        emit drawnDown(msg.sender, amount, block.timestamp, "Capital Drawn");
    }

    function loanRepayment( uint amount ) public {
        require(token.allowance(msg.sender, address(this)) >= amount * scconversion, "You have not approved the necessary amount for payment");
        require(token.balanceOf(msg.sender) >= amount, "You don't have sufficient amount in your stablecoin");

        token.transferFrom(msg.sender, address(this), amount * scconversion);
        emit repayLoan(msg.sender, amount, block.timestamp, "Loan Repaid");
    }

    function withdrawalApproval() public onlyOwner {
        uint allowance;
        require( balances[borrowerAdd] >= 0, "Borrower had no balance");
        require( token.balanceOf(address(this)) >=  0, "Insufficient amount in contract to repay");
        for (uint i = 1; i <= currentTid; i++) 
        {   
            address tempAddress = tokenId[i];
            require(repaymentBalance[tempAddress] >= 0, "all loans are repaid");
            allowance = token.allowance(address(this), tempAddress);
            token.approve(tempAddress, (allowance + (repayment[tempAddress] * scconversion)));
            repayToLender(tempAddress, repayment[tempAddress]);
        }
    }

    function withdrawal(address lender, uint amount) public {
        require( token.allowance(address(this), lender) >= amount * scconversion, "Do not have the allowance to withdraw, contact PeerHive admin");
        require( balances[lender] >= amount, "Insufficient balance");
        require( block.timestamp >= startDate + 30 days, "Withdrawal can only be done T+30");
        repaymentBalance[lender] -= amount;
        token.transfer(lender, amount * scconversion);
        emit Withdrawal(lender, amount, block.timestamp, "Withdraw");
    }

    function insufficientAmount() public {
        require(((principalAmount * tenthK ) / principalLimit ) < 8000, "Loan participation is less than 80%");
        require( block.timestamp < startDate, "Loan cannot be drawn before start date");  // Enforce start date
        require( token.balanceOf(address(this)) > 0, "Insufficient loan amount");
        loanDefault = false;
        loanStatus = false;
    }

    function insufficientWithdrawal(address lender, uint amount) public {
        require( ((principalAmount * tenthK ) / principalLimit ) < 8000, "Loan participation is less than 80%");
        require( !loanDefault && !loanStatus, "Loan is still active, contact admin");
        require( principalBalance[lender] > 0 && principalBalance[lender] >= amount, "You do not have any principal with this pool");
        principalBalance[lender] -= amount;
        token.transfer(lender, amount * scconversion);
        emit Withdrawal(lender, amount, block.timestamp, "Withdraw");
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount, block.timestamp, "Transfer");
    }

    function repayToLender(address to, uint amount) internal {
        _transfer(borrowerAdd, to, amount);
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}