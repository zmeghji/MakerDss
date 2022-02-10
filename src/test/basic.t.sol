// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../vat.sol";
import "../join.sol";


contract Basic is DSTest {

    Vat vat;
    GemJoin gemA;
    DSToken gold;
    address self;

    function setUp() public {
        vat = new Vat();
        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        // vat.init("gold");
        gemA = new GemJoin(address(vat), "gold", address(gold));

        self = address(this);
    }

    function testJoin() public {
        gemA.join(self, 1 ether);

        assertEq(gold.balanceOf(self), 999 ether);
        assertEq(gold.balanceOf(gemA.address), 1 ether);


    }
}