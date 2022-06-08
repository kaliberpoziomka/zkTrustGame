// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IHostAnswerVerifier.sol";
import "./interfaces/ICheckVerifier.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract zkTrustGame is Ownable {
    //variables
    uint256 public indexOfRoom;

    IHostAnswerVerifier hostAnswerVerifier;
    ICheckVerifier checkVerifier;

    // Room in players play
    struct Room {
        // addresses of players
        address[2] players;
        // balances of players in room
        mapping(address => uint256) balances;
        // hashed answers of players
        mapping(address => uint256) hashedAnswers;
        // turn of a game a in a room
        uint256 turn;
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
    function initRoom(
        uint256 _hostAnswerHash,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        address _token,
        uint256 _tokenAmount
    ) external {
        require(hostAnswerVerifier.verifyProof(a, b, c, [_hostAnswerHash]), 
               "Invalid host answer!");

        require(_token != address(0), "Token address cannot be 0.");
        require(_tokenAmount != 0, "Amount of tokens must be more than zero.");

        require(IERC20(_token).transferFrom(
                            msg.sender,
                            address(this),
                            _tokenAmount
                        ),
                "Tokens for game creation cannot be transfered. Please approve this contract for given amount of tokens.");

        Room storage currentRoom = rooms[indexOfRoom];
        currentRoom.turn++;
        currentRoom.players[0] = msg.sender;
        currentRoom.balances[msg.sender] = _tokenAmount;
        currentRoom.hashedAnswers[msg.sender] = _hostAnswerHash;
        
        indexOfRoom++;
    }
}