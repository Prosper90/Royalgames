// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "hardhat/console.sol";




contract Games is VRFConsumerBaseV2 {
    
    using SafeMath for uint256;

    VRFCoordinatorV2Interface COORDINATOR;

    //chainlink address for testnet sepolia  0x779877A7B0D9E8603169DdbD7836e478b4624789
    //chainlinkvrfaddress for testnet sepolia 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625

    //chainlink address for testnet goerli  0x326C977E6efc84E512bB9C30f76E30c160eD06FB
    //chainlinkvrfaddress for testnet goerli 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D

    //chainlink address for testnet bsc  	0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
    //chainlinkvrfaddress for testnet bsc 	0x699d428ee890d55D56d5FC6e26290f3247A762bd

    //chainlink address for mainnet  bsc 	0x404460C6A5EdE2D891e8297795264fDe62ADBB75
    //chainlinkvrfaddress for mainnet bsc   0x721DFbc5Cfe53d32ab00A9bdFa605d3b8E1f3f42

    address constant chainlinkaddress = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    address constant vrfWrapperAddress = 0x699d428ee890d55D56d5FC6e26290f3247A762bd;
    LinkTokenInterface  link = LinkTokenInterface (chainlinkaddress);

    uint64 subscriptionId;
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint32 constant callBackGasLimit = 600000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 3;

    address public owner;
    uint256 public minimumBet;
    // uint256 public houseEdge; // in percentage
    // uint256 public randomResult;

    //for flip
    enum BetOptions{ HEADS , TALES }

    //for sloth
    enum GameState {
        Waiting,
        Spinning,
        Completed
    }

    //bet status
    enum BetStatus { Pending, Win, Lose }

    // Union-like structure to hold data for both game types
    struct GameData {
        uint256 chosenNumber; // For dice game
        BetOptions input;     // For flip game
        GameState state;      // For sloth game
    }

    struct Bet {
        string  gameType;
        address player;
        uint256 betAmount;
        uint256 time;
        uint256 requestId;
        uint256 winChance;
        uint256 payout;
        BetStatus status;
        GameData gameData; // Common field to handle game-specific data
    }

    mapping(uint256 => Bet) public betsDetails;

    //users investment list
    Bet[] history;

    event BetPlaced(address indexed player, uint256 betAmount, string gameType , uint256 requestId);
    event BetResolved(address indexed player, uint256 betAmount, string gameType , uint256 requestId, BetStatus status);

    //For admin
        struct ETHPool
    {
        bool isAdded;
        uint256 ETHBalance;
        uint256 AddedAt;
    }
    mapping(uint256 => ETHPool) public EthereumPool;
        //referrals
    mapping(address => address) public referral;
    //leaderboards
    Bet[] winnersLeaders;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }


    constructor(uint256 _minimumBet, uint64 _subscriptionId, address _vrfCoordinator) payable VRFConsumerBaseV2(_vrfCoordinator)
    {
       owner = msg.sender;
       minimumBet = _minimumBet;
       COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
       subscriptionId = _subscriptionId;
       //houseEdge = _houseEdge;
    }


    function setMinimumBet(uint256 _minimumBet) external onlyOwner {
            minimumBet = _minimumBet;
    }

    // function setHouseEdge(uint256 _houseEdge) external onlyOwner {
    //     houseEdge = _houseEdge;
    // }


    function AddEthToContract(uint256 id) public onlyOwner payable returns(bool)
    {
        require(msg.value > 0, "0 value can't be added");

        EthereumPool[id] = ETHPool({
            isAdded: true,
            ETHBalance: msg.value,
            AddedAt: block.timestamp
        });

        return true;
    }

    // userside functions mappings , structs etc.
    function placeBet(uint256 _selectedChoice, string memory _gametype, uint256 _winChance, address _referral) external payable
    {   
        //require( FeeRequireMin <= msg.value, "Amount too small");
        //require(FeeRequireMax <= msg.value, "Amount too large");
        require(msg.value >= minimumBet, "Bet amount is below the minimum");

        // uint256 requestId = requestRandomness(callBackGasLimit, requestConfirmations, numWords);
        
        //main one

       uint256 requestId = COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callBackGasLimit,
        numWords
        );

        // betsDetails[requestId] = Bet(msg.sender, msg.value, chosenNumber, 0, BetStatus.Pending);
        // Set game-specific data based on the game type
        GameData memory gameData;
        if (keccak256(abi.encodePacked(_gametype)) == keccak256(abi.encodePacked("flip"))) {
            gameData.input = BetOptions(_selectedChoice);
        } else if (keccak256(abi.encodePacked(_gametype)) == keccak256(abi.encodePacked("dice"))) {
            gameData.chosenNumber = _selectedChoice;
        } else if (keccak256(abi.encodePacked(_gametype)) == keccak256(abi.encodePacked("sloth"))) {
            gameData.state = GameState.Spinning;
        }


        // console.log(requestId, "request id checking main");
    // notes -->  winChance is from 1 to 95, the lower it is the more the payout and harder to win. Its calculated from the frontend
    // notes --> payout is calculated from the amount played and win chance. Its calculated from the frontend
    // notes --> multiplier is also calculated from the winChance and amount played. Its calculated from the frontend
        betsDetails[requestId] = Bet({
            gameType: _gametype,
            player: msg.sender,
            betAmount: msg.value,
            time: block.timestamp,
            requestId: requestId,
            winChance: _winChance != 0 ? _winChance : 50,
            payout: msg.value,
            status: BetStatus.Pending,
            gameData: gameData
        });
        if(_referral != address(0)) {
           referral[msg.sender] = _referral;
        }
        
        // console.log(betsDetails[requestId], "checks normally");

        emit BetPlaced(msg.sender, msg.value, _gametype, uint256(requestId));

    }



    function fulfillRandomWords(uint256 requestId, uint256[] memory randomwords) internal override
    {
        Bet storage bet = betsDetails[requestId];
        uint256 payout;
            
            if(bet.winChance != 0) {
            // Calculate win percentage
             uint256 winPercent = 100 - bet.winChance;

            // Calculate multiplier and payout
             uint256 multiplier = 100 / winPercent;
             payout = bet.betAmount * multiplier;
            } else {
                payout = bet.payout * 2;
            }
   

        if(keccak256(bytes(bet.gameType)) == keccak256("Dice")) {
        //for dice
        require(bet.player != address(0), "Invalid request ID");
        require(bet.status == BetStatus.Pending, "Bet already resolved");

        uint256 diceResult = (randomwords[0] % 6) + 1;
        bool win = diceResult <= bet.gameData.chosenNumber;

        // Calculate payout
        // uint256 payout = calculatePayout(bet.betAmount, win);

        // Update bet status
        bet.status = win ? BetStatus.Win : BetStatus.Lose;

        // Transfer payout to the player
        if (win) {
        winnersLeaders.push(bet);
        if(referral[bet.player] != address(0)) {
                    //divide winning by referrer and referred
                    uint256 earnedRef =  payout.mul(3)/100;
                    
                    payable(referral[bet.player]).transfer(earnedRef);
                    payable(bet.player).transfer(payout);
                    //push to referrer history
                    // history.push(betDetails[requestId]);

                } else {

                    payable(bet.player).transfer(payout);
                }
                //push to referrer history
        }
            history.push(bet);

        } else if(keccak256(bytes(bet.gameType)) == keccak256("Flip")) {
            //for flip

            //  bet.fullFilled = true;
            // bet.randomWords = randomwords[0];

            BetOptions result = BetOptions.HEADS;

            if(randomwords[0] % 2 == 0)
            {
                result = BetOptions.TALES;
            } 

            //bettingDetails[requestId].input == result 
            //randomwords[0] % 10 < 4   
            bool win = bet.gameData.input == result;

            bet.status = win ? BetStatus.Win : BetStatus.Lose;

            if(win) {
                    winnersLeaders.push(bet);
                    if(referral[bet.player] != address(0)) {
                    //divide winning by referrer and referred
                    uint256 earnedRef =  payout.mul(3)/100;
                    
                    payable(referral[bet.player]).transfer(earnedRef);
                    payable(bet.player).transfer(payout);


                } else {

                    payable(bet.player).transfer(payout);

                }

                //push to referrer history
            }
            history.push(bet);

        
        } else if(keccak256(bytes(bet.gameType)) == keccak256("Sloth")) {

            require(uint256(bet.gameData.state) == uint256(GameState.Spinning), "Invalid spin state");


            uint256 result = randomwords[0] % 9; // Adjust based on the number of symbols

           // emit SpinCompleted(msg.sender, randomResult);
            bet.gameData.state = GameState.Completed;

            bool win = uint256(bet.gameData.state) == result;


            bet.status = win ? BetStatus.Win : BetStatus.Lose;

           if(win) {
                    winnersLeaders.push(bet);
                    if(referral[bet.player] != address(0)) {
                    //divide winning by referrer and referred
                    uint256 earnedRef =  payout.mul(3)/100;
                    
                    payable(referral[bet.player]).transfer(earnedRef);
                    payable(bet.player).transfer(payout);

                } else {

                    payable(bet.player).transfer(payout);

                }

                //push to referrer history
        }
         history.push(bet);


        }

       emit BetResolved(bet.player,  bet.betAmount,  bet.gameType ,  bet.requestId, bet.status);
    }




     function withdrawBalance(uint256 _amount) public onlyOwner
    {
        payable(owner).transfer(_amount);

    }


    function withdrawLink(uint256 _amount) public onlyOwner
    {
        require(_amount > 0, "Amount must be greater than zero");
        require(link.balanceOf(address(this)) >= _amount, "Not enough LINK balance");

        // Transfer LINK tokens to the sender (admin or owner)
        link.transfer(msg.sender, _amount);
    }

    


    function gameTracker() public view returns(Bet[] memory) {
        return history;
    }


     function linkBalance() public onlyOwner view returns(uint256 balance)  
    {
        uint256 bal = link.balanceOf(address(this));
        return bal;
    }


    function fund(uint96 amount) public  onlyOwner {
        link.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(subscriptionId)
        );
    }


    function cancelSubscription() external onlyOwner() {
        COORDINATOR.cancelSubscription(subscriptionId, msg.sender);
    }

    function transaferOwnership(address _address) public onlyOwner {
        require(_address != address(0), "Address is not correct");
        owner = _address;
    }
}