pragma solidity ^0.8.9;

interface IRace {
    function getGameBaseinfo(
        bytes32 _gameID
    ) external view returns (address owner, string memory title, address bundleAddr);
}
