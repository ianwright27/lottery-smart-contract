// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    /* Raffle Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleIninitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // =============================================================
    //                        ENTER RAFFLE
    // =============================================================

    function testRaffleRevertsWhenYouDontPayEnough() public {
        /**
         * Arrange -> Act -> Assert
         */
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        /* make sure some time has passed */
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 3);
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        // vm.expectRevert(Raffle.Raffle__UpkeepNotNeed.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    // =============================================================
    //                        CHECK UPKEEP
    // =============================================================

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 3);
        // act (we are not calling raffle.enterRaffle() therefore we will not fund the contract)
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure some time has passed
        vm.roll(block.number + 3); // increase block numbers
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("Raffle State: ", uint256(raffle.getRaffleState()));

        // Assert
        assert(upkeepNeeded == false);
    }

    // Challenge
    // testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed
    // testCheckUpkeepReturnsTrueWhenParametersAreGood

    // =============================================================
    //                     PERFORM UPKEEP
    // =============================================================
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure some time has passed
        vm.roll(block.number + 3); // increase block numbers

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance += entranceFee;
        numPlayers += 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeed.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnterred() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure some time has passed
        vm.roll(block.number + 3); // increase block numbers
        _;
    }

    // What if we need to get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnterred
    {
        // Arrange
        // ... modifier will enter raffle and advance time

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log("emitted requestedId: ", uint256(entries[1].topics[1]));
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0); // there is a requestId
        assert(uint256(raffleState) == 1); // CALCULATING
    }

    // =============================================================
    //                    FULFIL RANDOM WORDS
    // =============================================================
    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnterred {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnterred
    {
        // Arrange
        uint256 additionalEntrants = 3; // 4 people total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0); // OPEN
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
