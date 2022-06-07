pragma circom 2.0.0

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

//This circuit's task is to check if answer is in range 0-1
//and to compute a hash(salt, answer). This hash will be used later 
//in solidity smart contract logic. 
template CheckIncomingAnswer() {

    //private input - provided by host
    signal input salt;

    //public input - provided by player
    signal input answer;

    //outputs
    signal output answerHash;

    //components
    component lt = lessThan(32);
    component poseidon = Poseidon(2);

    //check if answer is 0 or 1
    lt.in[0] <== answer;
    lt.in[1] <== 2;
    lt.out === 1;

    //create hash from salt (from host) and answer (from player)
    //this hash will be further used for checking if answers are the same
    poseidon.inputs[0] <== salt;
    poseidon.inputs[1] <== answer;
    answerHash <== poseidon.out;
}

component main {public [answer]} = CheckIncomingAnswer();