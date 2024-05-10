// SPDX-License-Identifier: MIT
// Version: 0.0.0
pragma solidity >=0.7.3 <0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; // Import ERC721 first
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract PeerAgreement is ERC721, Ownable {

string private _baseTokenURI; // IPFS CID (or base URI if using on-chain storage)
   
  constructor(
    string memory baseTokenURI,
    string memory peerAgreementName,
    string memory peerAgreementID
  ) Ownable() ERC721(peerAgreementName,peerAgreementID){
        _baseTokenURI = baseTokenURI;
        
    }

   // Function to override the base URI for token metadata (onlyOwner)
    function setBaseURI(string memory baseTokenURI) external onlyOwner {
         _baseTokenURI = baseTokenURI;
    }

    function  _baseURI() internal view override returns (string memory){
         return _baseTokenURI;
    }

    

    // Define a struct to hold minimal agreement details
    struct AgreementDetails {
        address partyA;
        address partyB;
        uint256 timestamp;
        //Addition information of the agreement
    }

    // Mapping to store agreement details for each token ID
    mapping(uint256 => AgreementDetails) public agreementDetails;

    // Current token ID (starts at 1)
    uint256 public _currentTokenId = 0;

    // Function to mint a new NFT Agreement (private and onlyOwner)
    function mint(
        address to,
        address partyA,
        address partyB
        ) public onlyOwner {
        _currentTokenId++;
        _safeMint(to, _currentTokenId);
        agreementDetails[_currentTokenId] = AgreementDetails(partyA, partyB, block.timestamp);
    }

    // Modifier for restricted transfers
    modifier onlyParties(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId) || msg.sender == agreementDetails[tokenId].partyA || msg.sender == agreementDetails[tokenId].partyB, "Only parties involved can transfer");
    _;
    }

    // Function to transfer ownership with restrictions
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyParties(tokenId) {
        ERC721.transferFrom(from, to, tokenId);
    }  
}
