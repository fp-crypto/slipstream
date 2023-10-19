pragma solidity ^0.7.6;
pragma abicoder v2;

import {
    UniswapV3PoolSwapPartiallyStakedWithUnstakeFeeTest,
    CLGauge
} from "./UniswapV3PoolSwapPartiallyStakedWithUnstakeFee.t.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "contracts/periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";

contract MediumFee10to1Price2e18MaxRangeLiquidityPartiallyStakedWithUnstakedFeeTest is
    UniswapV3PoolSwapPartiallyStakedWithUnstakeFeeTest
{
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        string memory poolName = ".medium_fee_10to1_price_2e18_max_range_liquidity";
        address pool =
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: tickSpacing});

        uint160 startingPrice = encodePriceSqrt(10, 1);
        IUniswapV3Pool(pool).initialize(startingPrice);

        uint128 liquidity = 2e18;

        stakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        gauge = CLGauge(voter.gauges(pool));

        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 125_000);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            startingPrice,
            TickMath.getSqrtRatioAtTick(stakedPositions[0].tickLower),
            TickMath.getSqrtRatioAtTick(stakedPositions[0].tickUpper),
            stakedPositions[0].liquidity
        );

        vm.startPrank(users.alice);
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
            amount0 + 1,
            amount1 + 1,
            stakedPositions[0].tickLower,
            stakedPositions[0].tickUpper,
            tickSpacing,
            users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
            amount0 + 1,
            amount1 + 1,
            unstakedPositions[0].tickLower,
            unstakedPositions[0].tickUpper,
            tickSpacing,
            users.alice
        );

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = IUniswapV3Pool(pool).slot0();

        poolSetup = PoolSetup({
            poolName: poolName,
            pool: pool,
            gauge: address(gauge),
            poolBalance0: poolBalance0,
            poolBalance1: poolBalance1,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });
    }
}