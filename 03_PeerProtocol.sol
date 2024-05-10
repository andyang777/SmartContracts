// SPDX-License-Identifier: MIT
// Version: 0.0.1
pragma solidity >=0.7.3 <0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PeerContract is ERC1155, Ownable {

    string private _baseTokenURI;

    constructor(string memory baseTokenURI) ERC1155("") {
        _baseTokenURI = baseTokenURI;
    }

    // Function to override the base URI for token metadata (only owner)
    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    // This function correctly overrides the ERC1155's _baseURI function
    function _baseURI() internal view returns (string memory) {
        return _baseTokenURI;
    }

    function burn(uint256 _id, uint256 _amount) public {
        _burn(msg.sender, _id, _amount);
    }

    function mint(address _to, uint256 _id, uint256 _amount, bytes memory _data) public {
        _mint(_to, _id, _amount, _data);
    }

}