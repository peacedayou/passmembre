// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title PassMembre
/// @notice Billets d'événement et cartes de membre sous forme de NFT (ERC-721).
///         - Un billet peut être revendable ou non transférable (soulbound) : pas de marché noir.
///         - Chaque événement a une capacité maximale.
///         - Le contrôle à l'entrée marque le billet comme utilisé, une seule fois.
///         - Une carte de membre est valide jusqu'à sa date d'expiration.
contract PassMembre is ERC721, AccessControl {
    using Strings for uint256;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant CHECKER_ROLE = keccak256("CHECKER_ROLE");

    struct EventInfo {
        string name;
        uint64 startsAt;
        uint32 capacity;
        uint32 issued;
    }

    struct Pass {
        uint64 eventId;
        uint64 validUntil;
        bool soulbound;
        bool used;
    }

    uint64 public eventCount;
    uint256 public nextTokenId = 1;
    string private _base;

    mapping(uint64 => EventInfo) private _events;
    mapping(uint256 => Pass) private _passes;

    event EventCreated(uint64 indexed eventId, string name, uint64 startsAt, uint32 capacity);
    event PassIssued(uint256 indexed tokenId, uint64 indexed eventId, address indexed to, bool soulbound, uint64 validUntil);
    event CheckedIn(uint256 indexed tokenId, address indexed checker);
    event PassRevoked(uint256 indexed tokenId);

    error UnknownEvent();
    error SoldOut();
    error InvalidPass();
    error AlreadyUsed();
    error NonTransferable();
    error InvalidCapacity();

    constructor(string memory name_, string memory symbol_, string memory baseURI_, address admin)
        ERC721(name_, symbol_)
    {
        _base = baseURI_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(CHECKER_ROLE, admin);
    }

    // ------------------------------------------------------------- émission

    function createEvent(string calldata eventName, uint64 startsAt, uint32 capacity)
        external
        onlyRole(ISSUER_ROLE)
        returns (uint64 eventId)
    {
        if (capacity == 0) revert InvalidCapacity();
        eventId = ++eventCount;
        _events[eventId] = EventInfo(eventName, startsAt, capacity, 0);
        emit EventCreated(eventId, eventName, startsAt, capacity);
    }

    /// @param validUntil Horodatage d'expiration (0 = sans expiration).
    function issue(address to, uint64 eventId, uint64 validUntil, bool soulbound)
        external
        onlyRole(ISSUER_ROLE)
        returns (uint256 tokenId)
    {
        EventInfo storage e = _events[eventId];
        if (e.capacity == 0) revert UnknownEvent();
        if (e.issued >= e.capacity) revert SoldOut();
        e.issued += 1;

        tokenId = nextTokenId++;
        _passes[tokenId] = Pass(eventId, validUntil, soulbound, false);
        _safeMint(to, tokenId);
        emit PassIssued(tokenId, eventId, to, soulbound, validUntil);
    }

    /// @notice Annule un pass (remboursement, fraude). La place redevient disponible si l'événement n'est pas passé.
    function revoke(uint256 tokenId) external onlyRole(ISSUER_ROLE) {
        _requireOwned(tokenId);
        Pass memory p = _passes[tokenId];
        if (!p.used) _events[p.eventId].issued -= 1;
        delete _passes[tokenId];
        _burn(tokenId);
        emit PassRevoked(tokenId);
    }

    // ------------------------------------------------------------ contrôle

    /// @notice Le pass existe, n'est pas expiré et n'a pas encore servi.
    function isValid(uint256 tokenId) public view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;
        Pass memory p = _passes[tokenId];
        return !p.used && (p.validUntil == 0 || block.timestamp <= p.validUntil);
    }

    /// @notice Contrôle à l'entrée : vérifie et marque le billet comme utilisé, une seule fois.
    function checkIn(uint256 tokenId) external onlyRole(CHECKER_ROLE) {
        if (_ownerOf(tokenId) == address(0)) revert InvalidPass();
        Pass storage p = _passes[tokenId];
        if (p.used) revert AlreadyUsed();
        if (p.validUntil != 0 && block.timestamp > p.validUntil) revert InvalidPass();
        p.used = true;
        emit CheckedIn(tokenId, msg.sender);
    }

    // ---------------------------------------------------------------- vues

    function getEvent(uint64 eventId) external view returns (EventInfo memory) {
        if (_events[eventId].capacity == 0) revert UnknownEvent();
        return _events[eventId];
    }

    function getPass(uint256 tokenId) external view returns (Pass memory) {
        _requireOwned(tokenId);
        return _passes[tokenId];
    }

    function setBaseURI(string calldata baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _base = baseURI_;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat(_base, tokenId.toString(), ".json");
    }

    // ------------------------------------------------------------- interne

    /// @dev Bloque les transferts des pass non transférables (l'émission et la révocation restent possibles).
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0) && _passes[tokenId].soulbound) revert NonTransferable();
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
