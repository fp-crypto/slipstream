pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3PoolSwapTest} from "./UniswapV3PoolSwap.t.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

contract MediumFeeToken0LiquidityOnlyTest is UniswapV3PoolSwapTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        string memory poolName = ".medium_fee_token0_liquidity_only";
        address pool =
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: tickSpacing});

        uint160 startingPrice = encodePriceSqrt(1, 1);
        IUniswapV3Pool(pool).initialize(startingPrice);

        uint128 liquidity = 2e18;

        positions.push(Position({tickLower: 0, tickUpper: 2_000 * tickSpacing, liquidity: liquidity}));

        uniswapV3Callee.mint(pool, users.alice, positions[0].tickLower, positions[0].tickUpper, positions[0].liquidity);

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = IUniswapV3Pool(pool).slot0();

        poolSetup = PoolSetup({
            poolName: poolName,
            pool: pool,
            poolBalance0: poolBalance0,
            poolBalance1: poolBalance1,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });

        vm.startPrank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);
        vm.startPrank(users.alice);
    }
}