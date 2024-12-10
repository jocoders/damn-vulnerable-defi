// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title A Merkle Tree utility contract for Solidity
/// @notice Provides functions for Merkle proof verification and tree manipulation
contract Merkle {
    /// @notice Constructs a new Merkle contract instance
    constructor() {}

    /// @notice Verifies a Merkle proof for a given leaf and root
    /// @param root The root of the Merkle tree
    /// @param proof An array of bytes32 hashes that constitute the proof
    /// @param valueToProve The leaf value to prove
    /// @return True if the proof is valid, false otherwise
    function verifyProof(bytes32 root, bytes32[] memory proof, bytes32 valueToProve)
        external
        pure
        virtual
        returns (bool)
    {
        bytes32 rollingHash = valueToProve;
        uint256 length = proof.length;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                rollingHash = hashLeafPairs(rollingHash, proof[i]);
            }
        }
        return root == rollingHash;
    }

    /// @notice Hashes two leaf pairs in a specified order
    /// @dev This function uses inline assembly for optimized keccak256 hashing
    /// @param left The left leaf in the pair
    /// @param right The right leaf in the pair
    /// @return _hash The resulting hash of the leaf pair
    function hashLeafPairs(bytes32 left, bytes32 right) public pure returns (bytes32 _hash) {
        assembly {
            switch lt(left, right)
            case 0 {
                mstore(0x0, right)
                mstore(0x20, left)
            }
            default {
                mstore(0x0, left)
                mstore(0x20, right)
            }
            _hash := keccak256(0x0, 0x40)
        }
    }

    /// @notice Computes the root of a Merkle tree from an array of leaf values
    /// @param data An array of leaf values
    /// @return The computed root of the Merkle tree
    function getRoot(bytes32[] memory data) public pure virtual returns (bytes32) {
        require(data.length > 1, "won't generate root for single leaf");
        while (data.length > 1) {
            data = hashLevel(data);
        }
        return data[0];
    }

    /// @notice Generates a Merkle proof for a specific node
    /// @param data An array of leaf values
    /// @param node The index of the node to generate a proof for
    /// @return An array of bytes32 hashes that constitute the proof
    function getProof(bytes32[] memory data, uint256 node) public pure virtual returns (bytes32[] memory) {
        require(data.length > 1, "won't generate proof for single leaf");
        bytes32[] memory result = new bytes32[](log2ceilBitMagic(data.length));
        uint256 pos = 0;

        while (data.length > 1) {
            unchecked {
                if (node & 0x1 == 1) {
                    result[pos] = data[node - 1];
                } else if (node + 1 == data.length) {
                    result[pos] = bytes32(0);
                } else {
                    result[pos] = data[node + 1];
                }
                ++pos;
                node /= 2;
            }
            data = hashLevel(data);
        }
        return result;
    }

    /// @dev Helper function to hash a level of nodes in the Merkle tree
    /// @param data An array of leaf values from the current level
    /// @return An array of new hashes forming the next level
    function hashLevel(bytes32[] memory data) private pure returns (bytes32[] memory) {
        bytes32[] memory result;

        unchecked {
            uint256 length = data.length;
            if (length & 0x1 == 1) {
                result = new bytes32[](length / 2 + 1);
                result[result.length - 1] = hashLeafPairs(data[length - 1], bytes32(0));
            } else {
                result = new bytes32[](length / 2);
            }
            uint256 pos = 0;
            for (uint256 i = 0; i < length - 1; i += 2) {
                result[pos] = hashLeafPairs(data[i], data[i + 1]);
                ++pos;
            }
        }
        return result;
    }

    /// @notice Calculates the ceiling of the binary logarithm of a number
    /// @param x The number to calculate the log2 ceiling for
    /// @return The ceiling of the binary logarithm
    function log2ceil(uint256 x) public pure returns (uint256) {
        uint256 ceil = 0;
        uint256 pOf2;
        assembly {
            pOf2 := eq(and(add(not(x), 1), x), x)
        }
        unchecked {
            while (x > 0) {
                x >>= 1;
                ceil++;
            }
            ceil -= pOf2;
        }
        return ceil;
    }

    /// @notice Calculates the ceiling of the binary logarithm using bit manipulation
    /// @param x The number to calculate the log2 ceiling for
    /// @return The ceiling of the binary logarithm
    function log2ceilBitMagic(uint256 x) public pure returns (uint256) {
        if (x <= 1) {
            return 0;
        }
        uint256 msb = 0;
        uint256 _x = x;
        if (x >= 2 ** 128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2 ** 64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2 ** 32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2 ** 16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2 ** 8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2 ** 4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2 ** 2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2 ** 1) {
            msb += 1;
        }

        uint256 lsb = (~_x + 1) & _x;
        if ((lsb == _x) && (msb > 0)) {
            return msb;
        } else {
            return msb + 1;
        }
    }
}
