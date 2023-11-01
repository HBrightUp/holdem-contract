// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./NFTTemplate.sol";

contract Publisher {

    struct NFTInfo {
        address contractAddress;
        string name;
        string symbol;
        string uri;
    }

    mapping(address => address[]) private ownerNFTContracts;

    event PublishGame(
        address nftContract,
        string name,
        string symbol,
        string uri
    );

    constructor(){

    }

    function publishGame(
        string memory _name,
        string memory _symbol,
        string memory _url
    ) external returns (address) {
        // TODO:
        NFTTemplate nft = new NFTTemplate(msg.sender, _name, _symbol, _url);
        address nftAddr = address(nft);

        emit PublishGame(nftAddr, _name, _symbol, _url);

        ownerNFTContracts[msg.sender].push(nftAddr);

        return nftAddr;
    }

    function getOwnerNFTList(
        address _owner
    ) external view returns (NFTInfo[] memory) {
        uint256 len = ownerNFTContracts[_owner].length;
        address[] memory nftAddressList = ownerNFTContracts[_owner];
        NFTInfo[] memory nftInfoList = new NFTInfo[](len);

        for (uint256 i = 0; i < len; i++) {
            (
                string memory name,
                string memory symbol,
                string memory uri
            ) = getNFTInfo(NFTTemplate(nftAddressList[i]));
            nftInfoList[i] = NFTInfo({
                contractAddress: nftAddressList[i],
                name: name,
                symbol: symbol,
                uri: uri
            });
        }
        return nftInfoList;
    }

    function getNFTInfo(
        NFTTemplate _nftContract
    ) public view returns (string memory, string memory, string memory) {
        return (
            _nftContract.name(),
            _nftContract.symbol(),
            _nftContract.tokenURI(0)
        );
    }
}
