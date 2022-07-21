// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./FullMath.sol";
import "./Babylonian.sol";
import "./BitMath.sol";

// A library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint {
    // range: [0, 2**112 - 1]
    // resolution: 1 / 2**112
    struct uq112x112 {
        uint224 _x;
    }

    // range: [0, 2**144 - 1]
    // resolution: 1 / 2**112
    struct uq144x112 {
        uint256 _x;
    }

    uint8 public constant RESOLUTION = 112;
    uint256 public constant Q112 = 0x10000000000000000000000000000; // 2**112
    uint256 private constant Q224 =
        0x100000000000000000000000000000000000000000000000000000000; // 2**224
    uint256 private constant LOWER_MASK = 0xffffffffffffffffffffffffffff; // decimal of UQ*x112 (lower 112 bits)

    // Encode a uint112 as a UQ112x112
    function encode(uint112 x) internal pure returns (uq112x112 memory) {
        return uq112x112(uint224(x) << RESOLUTION);
    }

    // Encodes a uint144 as a UQ144x112
    function encode144(uint144 x) internal pure returns (uq144x112 memory) {
        return uq144x112(uint256(x) << RESOLUTION);
    }

    // Decode a UQ112x112 into a uint112 by truncating after the radix point
    function decode(uq112x112 memory self) internal pure returns (uint112) {
        return uint112(self._x >> RESOLUTION);
    }

    // Decode a UQ144x112 into a uint144 by truncating after the radix point
    function decode144(uq144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> RESOLUTION);
    }

    // Multiply a UQ112x112 by a uint, returning a UQ144x112
    // Reverts on overflow
    function mul(uq112x112 memory self, uint256 y)
        internal
        pure
        returns (uq144x112 memory)
    {
        uint256 z = 0;
        require(
            y == 0 || (z = self._x * y) / y == self._x,
            "FixedPoint::mul: Overflow"
        );
        return uq144x112(z);
    }

    // Multiply a UQ112x112 by an int and decode, returning an int
    // Reverts on overflow
    function muli(uq112x112 memory self, int256 y)
        internal
        pure
        returns (int256)
    {
        uint256 z = FullMath.mulDiv(self._x, uint256(y < 0 ? -y : y), Q112);
        require(z < 2**255, "FixedPoint::muli: Overflow");
        return y < 0 ? -int256(z) : int256(z);
    }

    // Multiply a UQ112x112 by a UQ112x112, returning a UQ112x112
    // Lossy
    function muluq(uq112x112 memory self, uq112x112 memory other)
        internal
        pure
        returns (uq112x112 memory)
    {
        if (self._x == 0 || other._x == 0) {
            return uq112x112(0);
        }
        uint112 upper_self = uint112(self._x >> RESOLUTION); // * 2^0
        uint112 lower_self = uint112(self._x & LOWER_MASK); // * 2^-112
        uint112 upper_other = uint112(other._x >> RESOLUTION); // * 2^0
        uint112 lower_other = uint112(other._x & LOWER_MASK); // * 2^-112

        // Partial products
        uint224 upper = uint224(upper_self) * upper_other; // * 2^0
        uint224 lower = uint224(lower_self) * lower_other; // * 2^-224
        uint224 uppers_lowero = uint224(upper_self) * lower_other; // * 2^-112
        uint224 uppero_lowers = uint224(upper_other) * lower_self; // * 2^-112

        // So the bit shift does not overflow
        require(upper <= uint112(-1), "FixedPoint::muluq: Upper overflow");

        // This cannot exceed 256 bits, all values are 224 bits
        uint256 sum =
            uint256(upper << RESOLUTION) +
                uppers_lowero +
                uppero_lowers +
                (lower >> RESOLUTION);

        // So the cast does not overflow
        require(sum <= uint224(-1), "FixedPoint::muluq: Sum overflow");

        return uq112x112(uint224(sum));
    }

    // Divide a UQ112x112 by a UQ112x112, returning a UQ112x112
    function divuq(uq112x112 memory self, uq112x112 memory other)
        internal
        pure
        returns (uq112x112 memory)
    {
        require(other._x > 0, "FixedPoint::divuq: Division by zero");
        if (self._x == other._x) {
            return uq112x112(uint224(Q112));
        }
        if (self._x <= uint144(-1)) {
            uint256 value = (uint256(self._x) << RESOLUTION) / other._x;
            require(value <= uint224(-1), "FixedPoint::divuq: Overflow");
            return uq112x112(uint224(value));
        }

        uint256 result = FullMath.mulDiv(Q112, self._x, other._x);
        require(result <= uint224(-1), "FixedPoint::divuq: Overflow");
        return uq112x112(uint224(result));
    }

    // Returns a UQ112x112 which represents the ratio of the numerator to the denominator
    // Can be lossy
    function fraction(uint256 numerator, uint256 denominator)
        internal
        pure
        returns (uq112x112 memory)
    {
        require(denominator > 0, "FixedPoint::fraction: Division by zero");
        if (numerator == 0) return FixedPoint.uq112x112(0);

        if (numerator <= uint144(-1)) {
            uint256 result = (numerator << RESOLUTION) / denominator;
            require(result <= uint224(-1), "FixedPoint::fraction: Overflow");
            return uq112x112(uint224(result));
        } else {
            uint256 result = FullMath.mulDiv(numerator, Q112, denominator);
            require(result <= uint224(-1), "FixedPoint::fraction: Overflow");
            return uq112x112(uint224(result));
        }
    }

    // Take the reciprocal of a UQ112x112
    // Reverts on overflow
    // Lossy
    function reciprocal(uq112x112 memory self)
        internal
        pure
        returns (uq112x112 memory)
    {
        require(self._x != 0, "FixedPoint::reciprocal: Reciprocal of zero");
        require(self._x != 1, "FixedPoint::reciprocal: Overflow");
        return uq112x112(uint224(Q224 / self._x));
    }

    // Square root of a UQ112x112
    // Lossy between 0/1 and 40 bits
    function sqrt(uq112x112 memory self)
        internal
        pure
        returns (uq112x112 memory)
    {
        if (self._x <= uint144(-1)) {
            return uq112x112(uint224(Babylonian.sqrt(uint256(self._x) << 112)));
        }

        uint8 safeShiftBits = 255 - BitMath.mostSignificantBit(self._x);
        safeShiftBits -= safeShiftBits % 2;
        return
            uq112x112(
                uint224(
                    Babylonian.sqrt(uint256(self._x) << safeShiftBits) <<
                        ((112 - safeShiftBits) / 2)
                )
            );
    }
}
