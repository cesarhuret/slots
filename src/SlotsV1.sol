//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "lib/chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "lib/chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract SlotsV1 is VRFConsumerBaseV2 {

    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;

    // Rinkeby only
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    uint32 callbackGasLimit = 200000;

    uint16 requestConfirmations = 3;

    uint32 numWords =  3;

    address s_owner;

    uint256 fee = 10 ** 17;

    mapping(address => uint256) public winnings;
    mapping(uint256 => Transaction) private history;

    struct Transaction {
        address sender;
        uint256 value;
    }

    event RequestSubmitted(address player, uint256 value, uint256 requestId, uint256 fee);
    event RequestFulfilled(uint256[3] randomWords);
    event RandomResultModulus(uint256 randomNumber1, uint256 randomNumber2, uint256 randomNumber3);
    event Prize(address player, string winnerMessage, uint256 prize);

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function deposit() payable public {}

    function play() public payable returns (uint256 requestId) {
        require(msg.value >= 0.05 ether, "The minimum bet is 0.05 ethers");
        require(address(this).balance >= msg.value * 2, "The pool doesn't have enough ethereum!");
        uint256 _requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        Transaction memory transaction;
        transaction.sender = msg.sender;
        transaction.value = msg.value;

        history[_requestId] = transaction;

        emit RequestSubmitted(msg.sender, msg.value, _requestId, fee);

        return _requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        
        emit RandomResultModulus((randomWords[0] % 10) + 1, (randomWords[1] % 10) + 1, (randomWords[2] % 10) + 1);

        address player = history[requestId].sender;
        uint256 value = history[requestId].value;

        uint256 prize;
        string memory winnerMessage = "You haven't won anything. Try again!";

        uint256[3] memory randomNumbers;
        randomNumbers[0] = (randomWords[0] % 10) + 1;
        randomNumbers[1] = (randomWords[1] % 10) + 1;
        randomNumbers[2] = (randomWords[2] % 10) + 1;

        if(randomNumbers[0] == 7 && randomNumbers[1] == 7 && randomNumbers[2] == 7) {
            prize = (address(this).balance)/2;
            winnings[player] += prize;
            
        } else if (randomNumbers[0] == randomNumbers[1] && randomNumbers[1] == randomNumbers[2]) {
            prize = 2 * value;
            winnings[player] += prize;
        } else if (randomNumbers[0] == 6 && randomNumbers[1] == 9 && randomNumbers[2] == 6) {
            prize = value + value/2;
        } else if (randomNumbers[0] + randomNumbers[1] + randomNumbers[2] == 21) {
            prize = value + value/5;
        }


        if (prize > 0) {
            // winnerMessage = string(bytes.concat(bytes("You won "), bytes(toString((prize)/10**18)), bytes(" ether!")));
            payable(address(player)).transfer(prize * value);
        }
        emit Prize(player, winnerMessage, prize);
    }

    function getBalance() public view returns (uint256 amount) {
        return address(this).balance;
    }

    function withdrawAll() public onlyOwner {
        require(address(this).balance >= 0);
        payable(msg.sender).transfer(address(this).balance);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    modifier onlyOwner {
        require(msg.sender == s_owner);
        _;
    }
}   