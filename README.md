# zkTrustGame
zkTrustGame is on-chain game based on game theory utilizing zero-knowledge proofs.

## Overview of the game
This is two-player game, where players can gain each other's tokens. If they cooperate, they can even steal tokens from the contract itself. If they both play poorly, they can both loose their tokens in favor of the game.

## How to play
General overview: The players are asked to put a coins into a basket. They have two possible moves - to cooperate (put a coins) or to cheat (pretend to put a coins). At each round players have to make a move without knowledge of other player's move in advance. At the end of each round, each player earn or looses coins according to the schema (assuming they put 2 coins):
- Both cooperate ---> Both get 3 coins
- One cheat, one cooperate ---> Cheater gets 4 coins, Cooperator looses 2 coins
- Both cheat ---> Both looses 2 coins

This allows players to earn or loose coins:
- One earns coins: other player looses
- Both earn coins: the game looses
- Game earns coins: both players loose

Initialization: The first player creates a room (becomes a host). During room creation player must send to the contract some amount of tokens (let's say 10 USDC). To other player can join, must also send the same amount of tokens.

Winners amounts: The possible amount of tokens that the player can get is >2x amount one player's deposit (1st player's tokens + 2nd player's tokens + some game's tokens). The possible amount that the game can loose is 1x amount one player deposit. The possible amount that the game can win is 2x amount one player deposit (1st player's tokens + 2nd player's tokens).

The game incetivize risky behavior i.e. cheating, since the player can get maximum amount only by cheating (2x). Also, when players cheat the game has a chance to earn coins from players. By cooperating players can maximally steal from the game 1x amount of tokens.

Game ends in two cases:
- at least one player has 0 balance - tokens of the loser are redistributed between the other player and the game
- sum of players' balances is equal to 3x inital one player's deposit