// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Makerdss.sol";

contract MakerdssTest is DSTest {
    Makerdss makerdss;

    function setUp() public {
        makerdss = new Makerdss();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
