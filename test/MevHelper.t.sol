pragma solidity ^0.7.5;

import "forge-std/Test.sol";

import { MevHelper } from "../src/MevHelper.sol";

abstract contract MevHelperBaseTest is Test {

        address constant factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        address constant tokenIn = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        address constant tokenOut = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

        MevHelper public helper;

        function setUp() public virtual {
                _deployMevHelper();
        }

        function _deployMevHelper() internal virtual;

        function testCalculationProfit() public {
                uint256 _before = gasleft();
                (uint256 priceOld, uint256 priceNew, uint256 diff) = helper.calculateSqrtpriceX96(factory, tokenIn, tokenOut, 500, 500000000);
                uint256 _after = gasleft();
                console.log("priceOld:", priceOld);
                console.log("priceNew:", priceNew);
                console.log("diff:", diff);
                console.log("Gas used:", (_before - _after));
        }
}

contract MevHelperSolTest is MevHelperBaseTest {
    function _deployMevHelper() internal override {
        helper = new MevHelper();
    }
}