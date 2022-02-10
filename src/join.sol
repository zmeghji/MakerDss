// SPDX-License-Identifier: AGPL-3.0-or-later


pragma solidity >=0.5.12;


//*** at this point it's not too clear what is meant by Gem like. The interface looks similar to ERC20 though
interface GemLike {
    function decimals() external view returns (uint);
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
}

//*** Not sure what DSTokenLike means, but it has a mint and burn function
interface DSTokenLike {
    function mint(address,uint) external;
    function burn(address,uint) external;
}

//*** Vat is one of the core contracts, but haven't gotten to that just yet
interface VatLike {
    function slip(bytes32,address,int) external;
    function move(address,address,uint) external;
}

/*
    Here we provide *adapters* to connect the Vat to arbitrary external
    token implementations, creating a bounded context for the Vat. The
    adapters here are provided as working examples:

      - `GemJoin`: For well behaved ERC20 tokens, with simple transfer
                   semantics.

      - `ETHJoin`: For native Ether.

      - `DaiJoin`: For connecting internal Dai balances to an external
                   `DSToken` implementation.

    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.

    Adapters need to implement two basic methods:

      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system

*/

contract GemJoin {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }
    modifier auth {
        require(wards[msg.sender] == 1, "GemJoin/not-authorized");
        _;
    }

    VatLike public vat;   // CDP Engine
    bytes32 public ilk;   // Collateral Type
    GemLike public gem;
    uint    public dec;
    uint    public live;  // Active Flag

    // Events
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);
    event Cage();

    constructor(address vat_, bytes32 ilk_, address gem_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        ilk = ilk_;
        gem = GemLike(gem_);
        dec = gem.decimals();
        emit Rely(msg.sender);
    }
    //*** cage method seems to be used in a lot of these contracts
    function cage() external auth {
        live = 0;
        emit Cage();
    }

    ///*** this method connects the gem to the vat */
    function join(address usr, uint wad) external {
        //***maybe a modifier for onlyLive would be better
        require(live == 1, "GemJoin/not-live");
        //*** Why cast to an int ? */
        require(int(wad) >= 0, "GemJoin/overflow");
        //*** increase users balance of ilk on the vat 
        vat.slip(ilk, usr, int(wad));
        require(gem.transferFrom(msg.sender, address(this), wad), "GemJoin/failed-transfer");
        emit Join(usr, wad);
    }
    //*** if join connects to the vat, then does exit disconnect?
    function exit(address usr, uint wad) external {
        require(wad <= 2 ** 255, "GemJoin/overflow");
        vat.slip(ilk, msg.sender, -int(wad));
        require(gem.transfer(usr, wad), "GemJoin/failed-transfer");
        emit Exit(usr, wad);
    }
}

//*** pretty similar to Dai join */
contract DaiJoin {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }
    modifier auth {
        require(wards[msg.sender] == 1, "DaiJoin/not-authorized");
        _;
    }

    VatLike public vat;      // CDP Engine
    DSTokenLike public dai;  // Stablecoin Token
    uint    public live;     // Active Flag

    // Events
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);
    event Cage();

    constructor(address vat_, address dai_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        dai = DSTokenLike(dai_);
    }
    function cage() external auth {
        live = 0;
        emit Cage();
    }
    //***not clear why 10**27 is used. It's 1 billion times 10**18 though so maybe that has significance */
    uint constant ONE = 10 ** 27;
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function join(address usr, uint wad) external {
        //*** uses move instead of slip like the  gem adaptor
        vat.move(address(this), usr, mul(ONE, wad));
        dai.burn(msg.sender, wad);
        emit Join(usr, wad);
    }
    function exit(address usr, uint wad) external {
        require(live == 1, "DaiJoin/not-live");
        vat.move(msg.sender, address(this), mul(ONE, wad));
        dai.mint(usr, wad);
        emit Exit(usr, wad);
    }
}
