pragma solidity >=0.5.0;

import "v3-core/contracts/libraries/LowGasSafeMath.sol";
import "v3-core/contracts/libraries/SafeCast.sol";
import "v3-core/contracts/libraries/FullMath.sol";
import "v3-core/contracts/libraries/UnsafeMath.sol";
import "v3-core/contracts/libraries/FixedPoint96.sol";
import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
}

contract MevHelper {

    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) public view returns (uint160) {
        // we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            uint256 product;
            if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1)
                    // always fits in 160 bits
                    return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
            }

            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96).add(amount)));
        } else {
            uint256 product;
            // if the product overflows, we know the denominator underflows
            // in addition, we must check that the denominator does not underflow
            require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
            uint256 denominator = numerator1 - product;
            return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
        }
    }

    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) public view returns (uint160) {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        if (add) {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? (amount << FixedPoint96.RESOLUTION) / liquidity
                        : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
                );

            return uint256(sqrtPX96).add(quotient).toUint160();
        } else {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                        : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
                );

            require(sqrtPX96 > quotient);
            // always fits 160 bits
            return uint160(sqrtPX96 - quotient);
        }
    }

    function getDec(address tokenIn, address tokenOut) public view  returns (uint8 dec0, uint8 dec1)  {
        dec0 = IERC20(tokenIn).decimals();
        dec1 = IERC20(tokenOut).decimals();
        return (dec0, dec1);
    }

    function calculateSqrtpriceX96(address factory, address tokenIn, address tokenOut, uint24 fee, uint256 amount) public view returns (uint256, uint256, uint256) {
        address pool = IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee);
        uint160 sqrt;
        {
            (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked) = IUniswapV3Pool(pool).slot0();
            sqrt = sqrtPriceX96;
        }

        uint160 sqrtPriceX96_new;
        {
            address token0 = IUniswapV3Pool(pool).token0();
            uint128 liquidity = IUniswapV3Pool(pool).liquidity();
            if(token0 == tokenIn) {
                sqrtPriceX96_new = getNextSqrtPriceFromAmount0RoundingUp(sqrt, liquidity, amount, true);
            } else {
                sqrtPriceX96_new = getNextSqrtPriceFromAmount1RoundingDown(sqrt, liquidity, amount, true);
            }
        }

        uint8 decimals;
        
        {
            (uint8 dec0, uint8 dec1) = getDec(tokenIn, tokenOut);
            if(dec0 > dec1){
                decimals = dec0 - dec1;
            } else if(dec0 < dec1) {
                decimals = dec1 - dec0;
            } else if (dec0 == dec1) {
                decimals = dec0;
            }
        }

        uint256 token1price;
        {
            token1price = (2 ** 192 / sqrt ** 2);
        }

        uint256 newtoken1price;
        {
            newtoken1price = (2 ** 192 / sqrtPriceX96_new ** 2);
        }


        return (token1price, newtoken1price, (newtoken1price - token1price));
    }
}