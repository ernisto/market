# Market

  Its a very WIP project to help you to handle developer products in your roblox game
  - Including API for waiting for a product purchase `market.await_prompt`
  - Giving directly products to player `market.give`
  - Stable gift system, currently with some engineering on profile store
  - Manage gamepasses as products, so it can be giftable too
  - Upload and auto complete dev product ids (in shared/market `.products`)
  - Custom product configs, such as discounts and bundles

  Currently i just moved my internal implementation from a game to a isolated repository,
so isnt really installable yet, im planning
  - create a pesde script to upload products instead of require mantle and
  another lune script to generate ProductId map (optional)
  - migrate from profile store (which needs a lot engineering for safe transactions) to
  my up coming re-store module
  - remove networking dependencies (currently im using blink)
  - refactor file system to a library like project, and publish to pesde
