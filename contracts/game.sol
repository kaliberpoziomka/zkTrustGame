// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IHostAnswerVerifier.sol";
import "./interfaces/ICheckVerifier.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract zkTrustGame is Ownable {
    //variables
    uint256 public roomId;

    IHostAnswerVerifier hostAnswerVerifier;
    ICheckVerifier checkVerifier;

    //points - should we let host to choose punctation?
    uint256 bothCoop = 2;
    uint256 cheatWinner = 4;
    uint256 cheatLoser = 1;
    uint256 bothCheat = 2;

    // Room in players play
    struct Room {
        // addresses of players
        address[2] players;
        // balances of players in room
        mapping(address => uint256) balances;
        // hashed answers of players
        mapping(address => uint256) hashedAnswers;
        // answer of a second player
        uint256 secondPlayerAnswer;
        // hash of salt chosen by host
        uint256 pubSaltHash;
        // maximum amount of coins that can be in players balances
        uint256 maxPlayerCoinSum;
        // ERC20 token addres which player play with
        address token;
        // move number of a game a in a room
        uint256 move;
        // address of a winner player
        address winner;
    }

    // mapping of rooms
    mapping(uint256 => Room) public rooms;

    constructor(
        address _hostAnswerVerifier,
        address _checkVerifier) {
            assert(_hostAnswerVerifier != address(0));
            assert(_checkVerifier != address(0));
            hostAnswerVerifier = IHostAnswerVerifier(_hostAnswerVerifier);
            checkVerifier = ICheckVerifier(_checkVerifier);
        }

    /// @notice Initializes room and submits first answer of host
    /// @dev To initialize the host answer circuit must be first run to create an hostAnswerHash and proof
    /// @param _hostAnswerHash is a hash produced in a circuit by host giving first answer 
    /// @param _hostSaltHash is a hash of salt used in a circuit

    function initRoom(
        uint256 _hostAnswerHash,
        uint256 _hostSaltHash,
        uint256[2] memory a, //proof
        uint256[2][2] memory b, //proof
        uint256[2] memory c, //proof
        address _token,
        uint256 _tokenAmount
    ) external {
        require(hostAnswerVerifier.verifyProof(a, b, c, [_hostAnswerHash, _hostSaltHash]), 
               "Invalid host answer!");

        require(_token != address(0), "Token address cannot be 0.");
        require(_tokenAmount != 0, "Amount of tokens must be more than zero.");

        require(IERC20(_token).transferFrom(
                            msg.sender,
                            address(this),
                            _tokenAmount
                        ),
                "Tokens for game creation cannot be transfered. Please make sure you have enough tokens and approve this conract for gien amount.");

        Room storage currentRoom = rooms[roomId];
        currentRoom.move++;
        currentRoom.token = _token;
        currentRoom.pubSaltHash = _hostSaltHash;
        currentRoom.players[0] = msg.sender;
        currentRoom.balances[msg.sender] = _tokenAmount;
        currentRoom.hashedAnswers[msg.sender] = _hostAnswerHash;
        currentRoom.maxPlayerCoinSum = 3 * _tokenAmount;
        
        roomId++;
    }

    function joinRoom(
        uint256 _roomId
    ) external {
        Room storage currentRoom = rooms[_roomId];

        require(currentRoom.players[1] == address(0), "Room is full");
        require(currentRoom.players[0] != msg.sender, "You can't play with yourself");

        address player1 = currentRoom.players[0];
        uint256 player1TokenAmount = currentRoom.balances[player1];
        require(IERC20(currentRoom.token).transferFrom(
                            msg.sender,
                            address(this),
                            player1TokenAmount
                        ),
                "You must transfer the same amount of tokens as host of the room. Plase approve this countract for given amount of tokens.");
        
        currentRoom.players[1] = msg.sender;
        currentRoom.balances[msg.sender] = player1TokenAmount;
    }

    /// @notice This function is to play as a second player
    function playAsPlayer(
        uint256 _roomId,
        uint256 _answer
    ) external {
        Room storage currentRoom = rooms[_roomId];

        require(currentRoom.move % 2 == 1, "It is time for opponent's move");
        require(currentRoom.players[1] == msg.sender, "It's not your room");
        require(currentRoom.winner == address(0), "Game is already over");

        currentRoom.secondPlayerAnswer = _answer;
        currentRoom.move++;
    }

    /// @notice This function is to play as a host
    function playAsHost(
        uint256 _roomId,
        uint256 _secondPlayerAnswerHash,
        uint256[2] memory a, //proof of 2nd player answer
        uint256[2][2] memory b, //proof of 2nd player answer
        uint256[2] memory c, //proof of 2nd player answer
        uint256 _newHostHashSalt,
        uint256 _newHostAnswerHash,
        uint256[2] memory aHost, //proof of host answer
        uint256[2][2] memory bHost, //proof of host answer
        uint256[2] memory cHost //proof of host answer
    ) external {
        Room storage currentRoom = rooms[_roomId];
        //checks for move validity
        require(currentRoom.move % 2 == 0, "It is time for opponent's move");
        require(currentRoom.players[0] == msg.sender, "It's not your room");
        require(currentRoom.winner == address(0), "Game is already over");
        //current room variables fetch
        address player2 = currentRoom.players[1];
        uint256 player2Balance = currentRoom.balances[player2];
        uint256 player1Balance = currentRoom.balances[msg.sender];
        uint256 _player2Answer = currentRoom.secondPlayerAnswer;
        uint256 _pubSaltHash = currentRoom.pubSaltHash;
        //verify proof of second player answer coputation by host
        require(checkVerifier.verifyProof(a, b, c, [_secondPlayerAnswerHash, _player2Answer, _pubSaltHash]));

        currentRoom.hashedAnswers[player2] = _secondPlayerAnswerHash;
        //update balances according to game logic
        updatePlayersBalances(_roomId);
        //check if the game shouldn't finish
        if(player1Balance + player2Balance >= currentRoom.maxPlayerCoinSum || player1Balance == 0 || player2Balance == 0) {
            //if game finishes choose winner and distribute tokens
            distributeCoinsBetweenWinnerAndGame(_roomId);
        } else {
            //if game is not finished, make next move by a host
            require(hostAnswerVerifier.verifyProof(aHost, bHost, cHost, [_newHostAnswerHash, _newHostHashSalt]), 
               "Invalid host answer!");
            currentRoom.move++;
            currentRoom.pubSaltHash = _newHostHashSalt;
            currentRoom.hashedAnswers[msg.sender] = _newHostAnswerHash;
        }
    }

    function updatePlayersBalances(uint256 _roomId) internal {
        Room storage currentRoom = rooms[_roomId];
        address player1 = currentRoom.players[0];
        address player2 = currentRoom.players[1];
        uint256 player2Answer = currentRoom.secondPlayerAnswer;
        //if they answer the same way:
        if(currentRoom.hashedAnswers[player1] == currentRoom.hashedAnswers[player2]){
            //if they cooperated (did not cheat):
            if(player2Answer == 0) {
                currentRoom.balances[player1] += bothCoop;
                currentRoom.balances[player2] += bothCoop;
            //if they both cheated:
            } else {
                currentRoom.balances[player1] = safeSubtract(currentRoom.balances[player1], bothCheat);
                currentRoom.balances[player2] = safeSubtract(currentRoom.balances[player2], bothCheat);
            }
        //if one of them cheated:
        } else {
            //if second player cooperated and second cheated
            if(player2Answer == 0) {
                currentRoom.balances[player1] += cheatWinner;
                currentRoom.balances[player2] = safeSubtract(currentRoom.balances[player2], cheatLoser);
            //if second player cheated and first cooperated
            } else {
                currentRoom.balances[player1] = safeSubtract(currentRoom.balances[player1], cheatLoser);
                currentRoom.balances[player2] += cheatWinner;
            }
        }
    }

    function safeSubtract(uint256 num1, uint256 num2) pure internal returns (uint256){
        if (num1 < num2) {
            return 0;
        } else {
            uint256 output = num1 - num2;
            return output;
        }
    }

    function distributeCoinsBetweenWinnerAndGame(uint256 _roomId) internal {
        Room storage currentRoom = rooms[_roomId];
        address player1 = currentRoom.players[0];
        address player2 = currentRoom.players[1];
        uint256 player1Balance = currentRoom.balances[player1];
        uint256 player2Balance = currentRoom.balances[player2];

        currentRoom.balances[player1] = 0;
        currentRoom.balances[player2] = 0;
        currentRoom.winner = player1Balance >= player2Balance ? player1 : player2;

        if (player1Balance == 0 || player2Balance == 0) {
            //if of them has more than zero:
            address winner;
            winner = player1Balance > 0 ? player1 : winner;
            winner = player2Balance > 0 ? player2 : winner;
            if (winner != address(0)) {
                uint256 amountToTransfer = (currentRoom.maxPlayerCoinSum / 3) * 2; //sum of tokens of player1 and player2 deposited
                require(IERC20(currentRoom.token).transfer(winner, amountToTransfer));
            }
            //if both has zero do nothing since tokens are already in contract
        } else {
            //if both gained enough coins so that sum of their balances is maximum mount of this room:
            require(player1Balance < currentRoom.maxPlayerCoinSum);
            require(player2Balance < currentRoom.maxPlayerCoinSum);
            uint256 sumPlayerTokens = player1Balance + player2Balance;
            uint256 amountOfTokensForGame = safeSubtract(sumPlayerTokens, currentRoom.maxPlayerCoinSum);
            //player2 is in worse position, host is a bit priviliged since has more things to setup a game. That's why only player 2 balance is shrinked is sum is bigger than amount
            player2Balance = safeSubtract(player2Balance, amountOfTokensForGame);
            require(IERC20(currentRoom.token).transfer(player1, player1Balance));
            require(IERC20(currentRoom.token).transfer(player2, player2Balance));
        }
    }
}