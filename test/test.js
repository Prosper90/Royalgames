const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Games Contract", function () {
  let owner;
  let gamesContract, vrfCoordinatorV2Mock;

  beforeEach(async () => {
    [owner, player] = await ethers.getSigners();
    const minimumAmount = hre.ethers.utils.parseEther("0.001");
    const initialAmount = hre.ethers.utils.parseEther("0.03");

    // Deploy Games contract
    const Games = await ethers.getContractFactory("Games");
    // Deploy VRF Coordinator Mock
    const VRFMock = await ethers.getContractFactory("VRFCoordinatorV2Mock");
    vrfCoordinatorV2Mock = await VRFMock.deploy(0, 0);
    await vrfCoordinatorV2Mock.createSubscription();
    await vrfCoordinatorV2Mock.fundSubscription(
      1,
      ethers.utils.parseEther("7")
    );

    gamesContract = await Games.deploy(
      minimumAmount,
      1,
      vrfCoordinatorV2Mock.address,
      {
        value: initialAmount,
      }
    );
  });
  // {
  //   value: ethers.utils.parseEther("1"),
  // }
  //vrfCoordinatorV2Mock.address
  it("should deploy properly", async () => {
    expect(gamesContract).to.be.an("object");
  });

  it("should place a bet successfully", async () => {
    const selectedChoice = 1; // replace with your chosen values
    const gameType = "dice"; // replace with your chosen values
    const winChance = 50; // replace with your chosen values
    const referralAddress = "0x0000000000000000000000000000000000000000"; // replace with your chosen values
    const betAmount = ethers.utils.parseEther("1"); // replace with your chosen bet amount

    await expect(
      gamesContract.placeBet(
        selectedChoice,
        gameType,
        winChance,
        referralAddress,
        {
          value: betAmount,
        }
      )
    )
      .to.emit(gamesContract, "BetPlaced")
      .withArgs(owner.address, betAmount, gameType, BigNumber.from(1));

    // Check the state of the contract if needed
    const bet = await gamesContract.betsDetails(BigNumber.from(1));
    console.log(bet, "checking something");
    expect(bet.player).to.equal(owner.address);
    expect(bet.gameType).to.equal("dice");
  });

  it("Coordinator should successfully receive the request", async function () {
    const selectedChoice = 1; // replace with your chosen values
    const gameType = "dice"; // replace with your chosen values
    const winChance = 50; // replace with your chosen values
    const referralAddress = "0x0000000000000000000000000000000000000000"; // replace with your chosen values
    const betAmount = ethers.utils.parseEther("1"); // replace with your chosen bet amount

    await expect(
      gamesContract.placeBet(
        selectedChoice,
        gameType,
        winChance,
        referralAddress,
        {
          value: ethers.utils.parseEther("1"),
        }
      )
    ).to.emit(vrfCoordinatorV2Mock, "RandomWordsRequested");
  });

  // it("Coordinator should fulfill Random Number request", async () => {
  //   const selectedChoice = 1; // replace with your chosen values
  //   const gameType = "dice"; // replace with your chosen values
  //   const winChance = 50; // replace with your chosen values
  //   const referralAddress = "0x0000000000000000000000000000000000000000"; // replace with your chosen values
  //   const betAmount = ethers.utils.parseEther("1"); // replace with your chosen bet amount

  //   const tx = await gamesContract.placeBet(
  //     selectedChoice,
  //     gameType,
  //     winChance,
  //     referralAddress,
  //     {
  //       value: ethers.utils.parseEther("1"),
  //     }
  //   );
  //   const { events } = await tx.wait();
  //   // console.log(events, "logging events");
  //   const [reqId] = events.filter((x) => x.event === "BetPlaced")[0].args;
  //   console.log(reqId, "let me see this bastard");

  //   // Add more assertions based on your contract's state
  //   await expect(
  //     vrfCoordinatorV2Mock.fulfillRandomWords(reqId, gamesContract.address)
  //   ).to.emit(vrfCoordinatorV2Mock, "RandomWordsFulfilled");
  // });

  it("Coordinator should fulfill Random Number request", async () => {
    const selectedChoice = 1; // replace with your chosen values
    const gameType = "dice"; // replace with your chosen values
    const winChance = 50; // replace with your chosen values
    const referralAddress = "0x0000000000000000000000000000000000000000"; // replace with your chosen values
    const betAmount = ethers.utils.parseEther("1"); // replace with your chosen bet amount

    const tx = await gamesContract
      .placeBet(selectedChoice, gameType, winChance, referralAddress, {
        value: ethers.utils.parseEther("1"),
      })
      .to.emit(vrfCoordinatorV2Mock, "RandomWordsRequested");
    let { events } = await tx.wait();

    let [reqId, invoker] = events.filter((x) => x.event === "BetPlaced")[0]
      .args;

    await expect(
      vrfCoordinatorV2Mock.fulfillRandomWords(reqId, gamesContract.address)
    ).to.emit(vrfCoordinatorV2Mock, "RandomWordsFulfilled");
  });

  it("should receive Random Numbers", async () => {
    const selectedChoice = 1; // replace with your chosen values
    const gameType = "dice"; // replace with your chosen values
    const winChance = 50; // replace with your chosen values
    const referralAddress = "0x0000000000000000000000000000000000000000"; // replace with your chosen values
    const betAmount = ethers.utils.parseEther("1"); // replace with your chosen bet amount

    const tx = await gamesContract.placeBet(
      selectedChoice,
      gameType,
      winChance,
      referralAddress,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    const { events } = await tx.wait();
    const [reqId] = events.filter((x) => x.event === "BetPlaced")[0].args;

    await new Promise((resolve) => setTimeout(resolve, 1000));

    await expect(
      vrfCoordinatorV2Mock.fulfillRandomWords(reqId, gamesContract.address)
    ).to.emit(gamesContract, "BetResolved");

    expect(await gamesContract.gameTracker()).to.have.lengthOf(1);
    const history = await gamesContract.gameTracker();
    expect(history).to.have.lengthOf(1);
    expect(history[0].player).to.equal(owner.address);
    const bet = await gamesContract.betsDetails(BigNumber.from(1));
    console.log(bet, "checking after call");
  });
});
