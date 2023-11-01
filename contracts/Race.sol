// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

// TODO: Access Control
contract Race {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    enum EntryType{
        Cash,
        Ticket,
        Gating
    }

    enum VoteType {
        ServerVoteTransactorDropOff,
        ClientVoteTransactorDropOff
    }

    enum RecipientSlotOwner {
        Unassigned,
        Assigned
    }

    enum RecipientSlotType {
        Token,
        Nft
    }

    enum SettleOp {
        Eject,
        Add,
        Sub
    }

    struct PlayerJoin {
        address addr;
        uint256 balance;
        uint16 position;
        uint64 accessVersion;
        string verifyKey;
    }

    struct ServerJoin {
        address addr;
        string endpoint;
        uint64 accessVersion;
        string verifyKey;
    }

    struct Vote {
        address voter;
        address votee;
        VoteType voteType;
    }

    struct EntryData {
        // Cash
        uint256 minDeposit;
        uint256 maxDeposit;
        // Ticket
        uint8 slotID;
        uint256 amount;
        // Gating
        string collection;
    }

    struct GameState {
        string title;
        string version;
        address bundleAddr;
        address token;
        address stakeAddr;
        uint16 maxPlayers;
        bytes data;
        address owner;
        address transactorAddr;
        uint64 accessVersion;
        uint64 settleVersion;
        uint64 unlockTime;
        PlayerJoin[] players;
        ServerJoin[] servers;
        Vote[] votes;
        bytes32 gameID;
        EntryType entryType;
        EntryData entryData;
        address recipientAccount;
        uint8[] checkpoint;
        uint64 checkpointAccessVersion;
    }

    struct ServerState {
        address owner;
        string endpoint;
    }

    struct SettleParams {
        address player;
        SettleOp operator;
        uint256 amount;
    }

    struct Recipient {
        address capAddr;
        RecipientSlot[] slots;
    }

    struct RecipientSlot {
        uint8 id;
        RecipientSlotType slotType;
        address tokenAddr;
        RecipientSlotShare[] shares;
    }

    struct RecipientSlotShare {
        RecipientSlotOwner ownerType;
        address owner;
        string id;
        uint16 weights;
        uint256 claimAmount;
    }

    struct TransferParams {
        uint8 slotID;
        uint256 amount;
    }

    mapping(address => Recipient) private recipients;
    // abi(recipientAddr+slotID+token)
    mapping(address => mapping(uint8 => uint256)) public recipientAmount;
    mapping(address => ServerState) private servers;

    uint16 public constant NAME_LEN = 16;
    uint16 public constant MAX_SERVER_NUM = 10;

    mapping(bytes32 => GameState) private games;
    mapping(address => bytes32[]) private nftGameList;

    // Event
    event CreateGame(bytes32 gameID, string title, address bundleAddress);

    event JoinGame(
        bytes32 gameID,
        address player,
        uint256 amount,
        uint16 position,
        uint64 accessVersion
    );

    event CloseGame(bytes32 gameID);

    event RegisterServer(address serverAddress, string endpoint);

    event ServeGame(address serverAddress, bytes32 gameID);

    event ReceiveClaim(address recipientAddr, address receiver, uint8 slotID, uint256 amount);

// <------------------------- Function ----------------------------------->
    function createRecipient(address _capAddr, RecipientSlot[] calldata _slots) external {
        require(_slots.length > 0, "empty slots");
        Recipient storage recipient = recipients[msg.sender];
        require(recipient.capAddr == address(0), "recipient already initialized");
        recipient.capAddr = _capAddr;
        for (uint8 i = 0; i < _slots.length; i++) {
            recipient.slots.push(_slots[i]);
        }
    }

    function getRecipient(address _recipientAddr) external returns (Recipient memory){
        return recipients[_recipientAddr];
    }

    function assignRecipient(address _recipientAddr, string memory _identifier, address _assignAddr) external checkRecipient(_recipientAddr) {
        Recipient storage recipient = recipients[_recipientAddr];
        for (uint8 i = 0; i < recipient.slots.length; i++) {
            for (uint8 j = 0; j < recipient.slots[i].shares.length; j++) {
                RecipientSlotShare storage share = recipient.slots[i].shares[j];
                if (share.ownerType == RecipientSlotOwner.Unassigned && _compareStr(share.id, _identifier)) {
                    share.owner = _assignAddr;
                    share.ownerType = RecipientSlotOwner.Assigned;
                }
            }
        }
    }

    function recipientClaim(address _recipientAddr) external checkRecipient(_recipientAddr) {
        Recipient storage recipient = recipients[_recipientAddr];
        for (uint8 i = 0; i < recipient.slots.length; i++) {
            RecipientSlot storage slot = recipient.slots[i];
            uint256 claim = _claimFromSlot(slot, recipientAmount[_recipientAddr][slot.id], msg.sender);
            if (claim > 0) {
                IERC20Upgradeable(slot.tokenAddr).transfer(msg.sender, claim);
                emit ReceiveClaim(_recipientAddr, msg.sender, slot.id, claim);
            }
        }
    }

    function createGameState(
        address _bundleAddr,
        address _tokenAddr,
        string memory _title,
        uint16 _maxPlayers,
        bytes memory _data,
        address _recipientAccount,
        EntryType entryType,
        EntryData memory entryData
    ) external returns (bytes32) {
        // TODO: check whether token is supported
        require(bytes(_title).length <= NAME_LEN, "title too long");
        bytes32 gameID = _generateUUID();
        GameState storage gameState = games[gameID];
        require(gameState.owner == address(0), "already initialized");
        gameState.gameID = gameID;
        gameState.version = "0.0.1";
        gameState.owner = msg.sender;
        gameState.title = _title;
        gameState.stakeAddr = address(this);
        gameState.bundleAddr = _bundleAddr;
        gameState.token = _tokenAddr;
        gameState.maxPlayers = _maxPlayers;
        gameState.data = _data;
        gameState.entryType = entryType;
        gameState.entryData = entryData;
        gameState.recipientAccount = _recipientAccount;

        emit CreateGame(gameID, _title, _bundleAddr);
        nftGameList[_bundleAddr].push(gameID);
        return gameID;
    }

    function getNFTGameList(
        address nftAddress
    ) external view returns (GameState[] memory) {
        bytes32[] memory gameIDs = nftGameList[nftAddress];
        return batchGetGameState(gameIDs);
    }

    function getGameState(
        bytes32 _gameID
    ) public view checkGame(_gameID) returns (GameState memory) {
        return games[_gameID];
    }

    function batchGetGameState(
        bytes32[] memory _gameIDs
    ) public view returns (GameState[] memory) {
        GameState[] memory gameList = new GameState[](_gameIDs.length);
        for (uint256 i = 0; i < _gameIDs.length; i++) {
            gameList[i] = getGameState(_gameIDs[i]);
        }
        return gameList;
    }

    modifier checkRecipient(address recipientAddr){
        Recipient storage recipient = recipients[recipientAddr];
        require(recipient.capAddr != address(0), "recipient uninitialized");
        _;
    }

    modifier checkGame(bytes32 _gameID) {
        GameState storage gameState = games[_gameID];
        require(gameState.owner != address(0), "game uninitialized");
        _;
    }

    modifier checkGameOwner(bytes32 _gameID) {
        GameState storage gameState = games[_gameID];
        require(gameState.owner != address(0), "game uninitialized");
        require(gameState.owner == msg.sender, "access denied");
        _;
    }

    function join(
        bytes32 _gameID,
        uint256 _amount,
        uint64 _accessVersion,
        uint16 _position,
        string memory _verifyKey
    ) external checkGame(_gameID) {
        GameState storage gameState = games[_gameID];

        require(
            gameState.players.length < gameState.maxPlayers,
            "game is already full"
        );

        require(_position < gameState.maxPlayers, "invalid position");

        if (gameState.entryType == EntryType.Cash) {
            require(gameState.entryData.minDeposit <= _amount && _amount <= gameState.entryData.maxDeposit, "deposit is invalid");
        } else if (gameState.entryType == EntryType.Ticket) {
            // TODO: Unimplemented;
        }


        for (uint256 i = 0; i < gameState.players.length; i++) {
            PlayerJoin memory player = gameState.players[i];

            require(player.addr != msg.sender, "player already joined");

            require(
                _position != player.position,
                "position already taken by another player"
            );
        }

        IERC20Upgradeable(gameState.token).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        gameState.accessVersion += 1;
        gameState.players.push(
            PlayerJoin({
                addr: msg.sender,
                balance: _amount,
                position: _position,
                accessVersion: gameState.accessVersion,
                verifyKey: _verifyKey
            })
        );
        emit JoinGame(_gameID, msg.sender, _amount, _position, _accessVersion);
    }

    function settle(
        bytes32 _gameID,
        SettleParams[] memory _params,
        TransferParams[] memory _transferParams,
        uint8[] memory _checkpoint
    ) external checkGame(_gameID) {
        GameState storage gameState = games[_gameID];

        uint256 addSum;
        uint256 subSum;
        uint256 ejectCount;
        for (uint256 i = 0; i < _params.length; i++) {
            if (_params[i].operator == SettleOp.Eject) {
                ejectCount += 1;
            }
        }
        address[] memory ejectList = new address[](ejectCount);
        uint256 ejectIdx;
        for (uint256 i = 0; i < _params.length; i++) {
            int256 playerIdx = _findPlayer(
                gameState.players,
                _params[i].player
            );
            require(playerIdx >= 0, "Invalid settle player address");
            PlayerJoin storage playerJoin = gameState.players[uint256(playerIdx)];
            if (_params[i].operator == SettleOp.Add) {
                // add
                playerJoin.balance = playerJoin.balance.add(_params[i].amount);
                addSum = addSum.add(_params[i].amount);
            } else if (_params[i].operator == SettleOp.Sub) {
                // sub
                playerJoin.balance = playerJoin.balance.sub(
                    _params[i].amount,
                    "invalid settle player amount"
                );
                subSum = subSum.add(_params[i].amount);
            } else if (_params[i].operator == SettleOp.Eject) {
                ejectList[ejectIdx] = _params[i].player;
                ejectIdx++;
            }
        }
        require(addSum == subSum, "Settle amounts are not sum up to zero");


        for (uint256 i = 0; i < ejectList.length; i++) {
            int256 playerIdx = _findPlayer(gameState.players, ejectList[i]);
            require(playerIdx >= 0, "Invalid settle player address");
            PlayerJoin storage playerJoin = gameState.players[
                                uint256(playerIdx)
                ];
            // transfer balance
            if (playerJoin.balance > 0) {
                IERC20Upgradeable(gameState.token).safeTransfer(
                    playerJoin.addr,
                    playerJoin.balance
                );
            }
            // remove from player list
            _removePlayer(gameState, uint256(playerIdx));
        }
        gameState.settleVersion += 1;
        gameState.checkpoint = _checkpoint;
        gameState.checkpointAccessVersion = gameState.accessVersion;

        // Handle commission
        if (gameState.recipientAccount != address(0)) {
            Recipient storage recipient = recipients[gameState.recipientAccount];
            for (uint8 i = 0; i < _transferParams.length; i++) {
                int256 idx = _findRecipientSlot(recipient.slots, _transferParams[i].slotID);
                require(idx >= 0, "invalid slot");
                RecipientSlot memory slot = recipient.slots[uint256(idx)];
                if (gameState.token != slot.tokenAddr) {
                    continue;
                }
                recipientAmount[gameState.recipientAccount][slot.id] = recipientAmount[gameState.recipientAccount][slot.id].add(_transferParams[i].amount);
            }
        }
    }


    function closeGame(bytes32 _gameID) external checkGameOwner(_gameID) {
        GameState storage gameState = games[_gameID];
        require(
            gameState.players.length == 0,
            "unable to close game that still has players in it"
        );

        delete games[_gameID];

        emit CloseGame(_gameID);
    }

    function registerServer(string memory endpoint) external {
        _registerServer(msg.sender, endpoint);
    }

    modifier checkServer(address serverAddr) {
        ServerState storage state = servers[serverAddr];
        require(state.owner != address(0), "Server Uninitialized");
        _;
    }

    function getServer(
        address serverAddr
    ) external view checkServer(serverAddr) returns (ServerState memory) {
        ServerState memory state = servers[serverAddr];
        return state;
    }

    function unServe(
        bytes32 _gameID
    ) external checkServer(msg.sender) checkGame(_gameID) {
        GameState storage gameState = games[_gameID];
        int256 idx = - 1;
        for (uint256 i = 0; i < gameState.servers.length; i++) {
            if (gameState.servers[i].addr == msg.sender) {
                idx = int256(i);
                break;
            }
        }
        require(idx >= 0, "server not found");
        for (uint256 i = uint256(idx); i < gameState.servers.length - 1; i++) {
            gameState.servers[i] = gameState.servers[i + 1];
        }
        gameState.servers.pop();
    }

    function serve(
        bytes32 _gameID,
        string memory _verifyKey
    ) external checkServer(msg.sender) checkGame(_gameID) {
        GameState storage gameState = games[_gameID];
        ServerState storage serverState = servers[msg.sender];
        require(
            gameState.servers.length < MAX_SERVER_NUM,
            "Server number exceeds the max of 10"
        );

        for (uint256 i = 0; i < gameState.servers.length; i++) {
            require(
                gameState.servers[i].addr != msg.sender,
                "Duplicate joining not allowed as the server already joined"
            );
        }
        uint64 newAccessVersion = gameState.accessVersion + 1;
        if (
            gameState.transactorAddr == address(0) ||
            gameState.servers.length == 0
        ) {
            gameState.transactorAddr = msg.sender;
        }
        gameState.servers.push(
            ServerJoin({
                addr: msg.sender,
                endpoint: serverState.endpoint,
                accessVersion: newAccessVersion,
                verifyKey: _verifyKey
            })
        );
        gameState.accessVersion = newAccessVersion;
        emit ServeGame(msg.sender, _gameID);
    }


    function getGameBaseinfo(
        bytes32 _gameID
    )
    external
    view
    checkGame(_gameID)
    returns (address owner, string memory title, address bundleAddr)
    {
        GameState memory gameState = games[_gameID];

        return (gameState.owner, gameState.title, gameState.bundleAddr);
    }

    function vote(
        bytes32 _gameID,
        address _voteeAddr,
        VoteType _voteType
    ) external checkGame(_gameID) {
        GameState storage gameState = games[_gameID];
        if (
            gameState.transactorAddr != msg.sender || _voteeAddr == msg.sender
        ) {
            revert("Invalid votee account");
        }
        if (_voteType == VoteType.ServerVoteTransactorDropOff) {
            for (uint8 i; i < gameState.servers.length; i++) {
                require(
                    gameState.servers[i].addr == _voteeAddr,
                    "Invalid votee account"
                );
            }
            gameState.votes.push(
                Vote({
                    voter: msg.sender,
                    votee: _voteeAddr,
                    voteType: _voteType
                })
            );
            // TODO:
            // let clock = Clock::get()?.epoch;
            // if game_state.votes.len() >= game_state.servers.len() / 2 {
            //     game_state.unlock_time = Some(clock + 10_000);
            // }
        } else if (_voteType == VoteType.ClientVoteTransactorDropOff) {
            // TODO: Unimplemented
        }
    }

    function _compareStr(string memory a, string memory b) internal pure returns (bool){
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _claimFromSlot(RecipientSlot storage slot, uint256 stakeAmount, address owner) internal returns (uint256){
        uint16 totalWeight = 0;
        uint256 totalAmount = stakeAmount;
        for (uint8 i = 0; i < slot.shares.length; i++) {
            totalWeight += slot.shares[i].weights;
            totalAmount += slot.shares[i].claimAmount;
        }
        for (uint8 i = 0; i < slot.shares.length; i++) {
            RecipientSlotShare storage share = slot.shares[i];
            if (share.owner == owner) {
                uint256 claim = totalAmount.mul(uint256(share.weights)).div(uint256(totalWeight)).sub(share.claimAmount);
                share.claimAmount += claim;
                return claim;
            }
        }
        return 0;
    }


    function _findRecipientSlot(RecipientSlot[] memory slots, uint8 slotID) internal pure returns (int256){
        for (uint256 i = 0; i < slots.length; i++) {
            if (slots[i].id == slotID) {
                return int256(i);
            }
        }
        return - 1;
    }

    function _findPlayer(
        PlayerJoin[] memory playerList,
        address targetAddr
    ) internal pure returns (int256) {
        for (uint256 i = 0; i < playerList.length; i++) {
            if (playerList[i].addr == targetAddr) {
                return int256(i);
            }
        }
        return - 1;
    }

    function _registerServer(
        address _serverAddr,
        string memory _endpoint
    ) internal {
        ServerState storage state = servers[_serverAddr];

        state.owner = _serverAddr;
        state.endpoint = _endpoint;

        emit RegisterServer(_serverAddr, _endpoint);
    }

    function _removePlayer(GameState storage state, uint256 idx) internal {
        for (uint256 i = idx; i < state.players.length - 1; i++) {
            state.players[i] = state.players[i + 1];
        }
        state.players.pop();
    }

    function _generateUUID() internal view returns (bytes32 uuid) {
        uuid = keccak256(
            abi.encodePacked(msg.sender, blockhash(block.number - 1))
        );
        while (games[uuid].owner != address(0)) {
            uuid = (keccak256(abi.encodePacked(uuid)));
        }
        return uuid;
    }
}
