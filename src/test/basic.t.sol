// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../vat.sol";
import "../join.sol";

contract TestVat is Vat {
    uint256 constant ONE = 10 ** 27;
    function mint(address usr, uint wad) public {
        dai[usr] += wad * ONE;
        debt += wad * ONE;
    }
}
contract Basic is DSTest {

    TestVat vat;
    GemJoin gemA;
    DSToken gold;

    DaiJoin daiA;
    DSToken dai;
    address self;

    function setUp() public {
        vat = new TestVat();
        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        vat.init("gold");
        gemA = new GemJoin(address(vat), "gold", address(gold));
        vat.rely(address(gemA));

        dai  = new DSToken("Dai");
        daiA = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiA));
        dai.setOwner(address(daiA));

        self = address(this);

    }

    function testGemJoin() public {

        gold.approve(address(gemA), 1 ether);
        gemA.join(self, 1 ether);

        assertEq(gold.balanceOf(self), 999 ether);
        assertEq(gold.balanceOf(address(gemA)), 1 ether);

        assertEq(vat.gem("gold", self), 1 ether);
    }

    function testGemExit() public {
        gold.approve(address(gemA), 2 ether);
        gemA.join(self, 2 ether);

        assertEq(vat.gem("gold", self), 2 ether);
        assertEq(gold.balanceOf(self), 998 ether);

        gemA.exit(self, 1 ether);

        assertEq(vat.gem("gold", self), 1 ether);
        assertEq(gold.balanceOf(self), 999 ether);
    }

    function testDaiExit() public {
        vat.mint(address(this), 1 ether);
        vat.hope(address(daiA));
        daiA.exit(self, 1 ether);
        assertEq(dai.balanceOf(self), 1 ether);
        assertEq(vat.dai(self), 0);
        assertEq(vat.dai(address(daiA)), (1 ether)*10**27);

    }
    function testDaiJoin() public{
        vat.mint(address(this), 1 ether);
        vat.hope(address(daiA));
        daiA.exit(self, 1 ether);

        dai.approve(address(daiA), 1 ether);
        daiA.join(self, 1 ether);

        assertEq(vat.dai(self), (1 ether)*10**27);
        assertEq(dai.balanceOf(self), 0 ether);

    }

    function testFrob() public {
        vat.file("Line", (1 ether)*10**27);
        vat.file("gold", "line",  (1 ether)*10**27);
        vat.file("gold", "spot",  (10**27));


        gold.approve(address(gemA), 1 ether);
        gemA.join(self, 1 ether);
        assertEq(vat.gem("gold", self), 1 ether);

        vat.frob("gold", self, self, self, 1 ether, 1 ether);

        assertEq(vat.gem("gold", self), 0);
        (uint ink , uint art) = vat.urns("gold", self);
        assertEq(ink, 1 ether);

        assertEq(vat.dai(self), (1 ether)*10**27);
        vat.hope(address(daiA));
        daiA.exit(self, 1 ether);

        assertEq(dai.balanceOf(self), 1 ether);
        assertEq(vat.dai(self), 0 );

    }
}