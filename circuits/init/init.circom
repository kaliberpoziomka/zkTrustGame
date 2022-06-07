pragma circom 2.0.0

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

//This circuit's taks is to create locally salted hash of answer
//provided by host. It lets other player to be sure, that
//the host created hash only from salt and answer, and that the answer
//is number between 0 and 1, without knwoing the answer in advance.
template Init() {
    //private input - provided by host
    signal input salt;
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

    //create hash from salt (from host) and answer (also from host)
    //this hash will be further used for checking if answers are the same
    poseidon.inputs[0] <== salt;
    poseidon.inputs[1] <== answer;
    answerHash <== poseidon.out;
}

component main = Init();