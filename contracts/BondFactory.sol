// SPDX-License-Identifier: AGPL
pragma solidity 0.8.9;
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Bond.sol";

/** 
    @title Bond Factory
    @author Porter Finance
    @notice This factory contract issues new bond contracts
    @dev This uses a cloneFactory to save on gas costs during deployment https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones
*/
contract BondFactory is AccessControl {
    address public immutable tokenImplementation;
    bool public isAllowListEnabled = true;
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    /**
        @notice Emitted when a new bond is created
        @param newBond The address of the newley deployed bond
        note: inherit the rest of the paramters from createBond
    */
    event BondCreated(
        address newBond,
        string name,
        string symbol,
        address indexed owner,
        uint256 maturityDate,
        address indexed repaymentToken,
        address indexed collateralToken,
        uint256 backingRatio,
        uint256 convertibilityRatio
    );

    /// @notice Emitted when the allow list is toggled on or off
    /// @param isAllowListEnabled the new state of the allow list
    event AllowListEnabled(bool isAllowListEnabled);

    /// @dev If allow list is enabled, only allow listed issuers are able to call functions
    modifier onlyIssuer() {
        if (isAllowListEnabled) {
            _checkRole(ISSUER_ROLE, msg.sender);
        }
        _;
    }

    constructor() {
        tokenImplementation = address(new Bond());
        // this grants the user deploying this contract the DEFAULT_ADMIN_ROLE
        // which gives them the ability to call grantRole to grant access to
        // the ISSUER_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Turns the allow list on or off
    /// @param _isAllowListEnabled If the allow list should be enabled or not
    /// @dev Must be called by the current owner
    function setIsAllowListEnabled(bool _isAllowListEnabled)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isAllowListEnabled = _isAllowListEnabled;
        emit AllowListEnabled(isAllowListEnabled);
    }

    /// @notice Creates a bond
    /// @param name Name of the bond
    /// @param symbol Ticker symbol for the bond
    /// @param owner Owner of the bond
    /// @param maturityDate Timestamp of when the bond matures
    /// @param collateralToken Address of the collateral to use for the bond
    /// @param backingRatio Ratio of bond: collateral token
    /// @param repaymentToken Address of the token being paid
    /// @param convertibilityRatio Ratio of bond:token that the bond can be converted into
    /// @dev This uses a clone to save on deployment costs https://github.com/porter-finance/v1-core/issues/15 which adds a slight overhead everytime users interact with the bonds - but saves 10x the gas during deployment
    function createBond(
        string memory name,
        string memory symbol,
        address owner,
        uint256 maturityDate,
        address repaymentToken,
        address collateralToken, // todo collateralToken
        uint256 backingRatio, // collateralRatio
        uint256 convertibilityRatio, // todo convertibleRatio - convertibleToken
        uint256 maxSupply
    ) external onlyIssuer returns (address clone) {
        clone = Clones.clone(tokenImplementation);
        Bond(clone).initialize(
            name,
            symbol,
            owner,
            maturityDate,
            repaymentToken,
            collateralToken,
            backingRatio,
            convertibilityRatio,
            maxSupply
        );
        emit BondCreated(
            clone,
            name,
            symbol,
            owner,
            maturityDate,
            repaymentToken,
            collateralToken,
            backingRatio,
            convertibilityRatio
        );
    }
}