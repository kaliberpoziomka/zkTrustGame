// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IInitVerifier.sol";
import "./interfaces/ICheckVerifier.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game {
    //variables
    uint256 public gameIndex;

    IInitVerifier initVerifier;
    ICheckVerifier checkVerifier;

    constructor(
        address _initVerifier,
        address _checkVerifier) {
            initVerifier = IInitVerifier(_initVerifier);
            checkVerifier = ICheckVerifier(_checkVerifier);
        }
    
    function initGame(
        uint256 _initHash,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        address _token,
        uint256 _tokenAmount
    ) external {
        require(initVerifier.verifyProof(a, b, c, [_initHash]), 
               "Invalid initialization!");

        require(_token != address(0), "Token address cannot be 0.");
        require(_tokenAmount != 0, "Amount of tokens must be more than zero.");

        require(IERC20(_token).transferFrom(
                            msg.sender,
                            address(this),
                            _tokenAmount
                        ),
                "Tokens for game creation cannot be transfered. Please approve this contract for given amount of tokens.");

    }
}