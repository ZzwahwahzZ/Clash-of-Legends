# Asset source audit

The project owner account contains a separate source repository: https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets.

A read-only recursive Git tree inspection on 2026-11-05 found 333 entries (311 files, 22 directories; 405,518,322 tracked bytes). It includes 42 GLB/OBJ reconstruction candidates: 20 characters, 5 map references, 5 mounts, 1 equipment reference, and 11 monsters. It also includes previews, source images, reports, and UV/vertex-color experiments.

The source repository publishes an extracted archive (842,723,106 bytes; SHA-256 0d21a110c09b762ed5f1a5f4da022857b0534e489eb85052d15da460cb229d2a), a prepared archive (108,387,746 bytes; SHA-256 18c6a3f4461fb01827436466c3af18ec782cf5555793c7ac32a198030db75c26), and a supplemental archive (435,948,386 bytes; SHA-256 28233860b864efc0fc5a9181c18ca2f0ee9a4c4f3441a689b3c9f5f91d34f7f7). These are source-release metadata values, not independently downloaded and rehashed in this audit.

The 42-model geometry report marks models as rendered but reports watertight=false for every model. UV projection is demonstrated on only 3 character models and is explicitly a test, not production PBR texturing. Rigging, skinning, animation clips, complete traversable maps, and a full equipment wardrobe are not established by the inspected reports.

These assets are a useful private reference and reconstruction starting point, not finished production game content. Public repository visibility does not grant rights to redistribute proprietary client assets or derivative copies. Ship only original or properly licensed production assets. Do not publish these source archives as in-game resource packs.

The in-game PCK packages and downloader remain unimplemented until rights-cleared production assets are created, packaged, hashed, and tested.