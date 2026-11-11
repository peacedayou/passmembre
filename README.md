# PassMembre

Billets d'événement et cartes de membre en **NFT** pour les associations, clubs étudiants et
organisateurs d'événements. Contrat ERC-721 testé (Foundry, fuzzing, Slither).

| Fonction | Ce que ça règle |
| --- | --- |
| **Capacité par événement** | Impossible d'émettre plus de billets que de places (vérifié par fuzzing) |
| **Pass non transférable** (soulbound) | Pas de revente au noir, ni de prêt d'une carte de membre |
| **Billets revendables** au choix | Pour les événements où la revente est permise |
| **Contrôle à l'entrée** | Un rôle « contrôleur » valide le billet une seule fois |
| **Cartes de membre avec expiration** | Valides jusqu'à une date, renouvelables par une nouvelle émission |
| **Révocation** | Remboursement ou fraude : le pass est détruit et la place libérée |
| **Rôles séparés** | Administrateur, émetteur et contrôleur (OpenZeppelin AccessControl) |

## Démarrage

```bash
forge test
ADMIN=0x... BASE_URI=https://exemple.com/meta/ \
  forge script script/Deploy.s.sol --rpc-url $RPC_URL --account deployer --broadcast
```

## Modèle d'affaires

Frais par événement ou abonnement annuel pour les associations. Le paiement des billets peut passer par
[PayStable](https://github.com/peacedayou/paystable) (USDC versé directement à l'organisateur).

## Feuille de route

Application de contrôle à l'entrée (code QR et signature du portefeuille), page d'achat, métadonnées
et images générées, déploiement sur Base pour des frais de quelques cents.

Les contrats n'ont pas fait l'objet d'un audit externe.
