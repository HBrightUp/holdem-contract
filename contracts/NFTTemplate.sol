pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTTemplate is ERC721 {
    string private url;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _url
    ) ERC721(_name, _symbol) {
        url = _url;
        _mint(_owner, 0);
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        return url;

        // _requireMinted(tokenId);

        // string memory baseURI = _baseURI();
        // return
        //     bytes(baseURI).length > 0
        //         ? string(abi.encodePacked(baseURI, tokenId.toString()))
        //         : "";
    }
}
