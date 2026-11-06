import io, json, pathlib, subprocess, sys, tempfile, unittest, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCANNER = ROOT / "tools/asset_forensics/run_forensics.py"

class ForensicsPipelineTests(unittest.TestCase):
    def test_nested_zip_inventory_and_categories(self):
        with tempfile.TemporaryDirectory() as td:
            base=pathlib.Path(td); nested=io.BytesIO()
            with zipfile.ZipFile(nested,"w",zipfile.ZIP_DEFLATED) as z:
                z.writestr("config/3dskeleton.ini","[Skeleton]\nCount=3\n")
                z.writestr("motions/warrior_attack.ani",b"ANIMDATA")
            archive=base/"source.zip"
            with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as z:
                z.writestr("models/warrior.fbx",b"FBXDATA")
                z.writestr("audio/battle.ogg",b"OggS"+b"\0"*32)
                z.writestr("nested/resources.zip",nested.getvalue())
            out=base/"out"
            p=subprocess.run([sys.executable,str(SCANNER),str(archive),"--out",str(out)],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)
            report=json.loads((out/"forensic-report.json").read_text())
            self.assertGreaterEqual(report["file_count"],5)
            self.assertGreaterEqual(report["category_counts"]["skeleton"],1)
            self.assertGreaterEqual(report["category_counts"]["motion"],1)
            self.assertTrue((out/"resource-candidates.csv").is_file())
            self.assertTrue((out/"extracted/root/nested/resources_contents/config/3dskeleton.ini").is_file())


    def test_verified_asset_promotion_builds_runtime_catalog(self):
        with tempfile.TemporaryDirectory() as td:
            base=pathlib.Path(td); project=base/"project"; source=base/"source"
            project.mkdir(); source.mkdir()
            (source/"rig.bin").write_bytes(b"verified skeleton")
            (source/"hero.glb").write_bytes(b"verified glb")
            import hashlib
            digest=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
            manifest={"manifest_version":1,"assets":[
                {"id":"rig_trojan","category":"skeletons","source":"rig.bin","target":"assets/imported/rigs/trojan.json","sha256":digest(source/"rig.bin"),"asset_role":"skeleton","mapping_status":"verified"},
                {"id":"hero_trojan_male","category":"characters","source":"hero.glb","target":"assets/imported/characters/trojan_male.glb","sha256":digest(source/"hero.glb"),"asset_role":"complete_character","mapping_status":"verified","character_class":"Trojan","gender":"male","rig_id":"rig_trojan","depends_on":["rig_trojan"]}
            ]}
            manifest_path=base/"approved.json"; manifest_path.write_text(json.dumps(manifest))
            builder=ROOT/"tools/asset_forensics/build_godot_catalog.py"
            p=subprocess.run([sys.executable,str(builder),str(project),str(source),str(manifest_path),"--apply"],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)
            catalog=json.loads((project/"resource_stage/world/resource_catalog.json").read_text())
            hero=catalog["assets"]["characters"][0]
            self.assertEqual(hero["mapping_status"],"verified")
            self.assertEqual(hero["rig_id"],"rig_trojan")
            self.assertTrue((project/"assets/imported/characters/trojan_male.glb").is_file())

    def test_zip_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            base=pathlib.Path(td); archive=base/"bad.zip"
            with zipfile.ZipFile(archive,"w") as z:
                z.writestr("../escape.txt","must not escape")
            out=base/"out"
            p=subprocess.run([sys.executable,str(SCANNER),str(archive),"--out",str(out)],capture_output=True,text=True)
            self.assertEqual(p.returncode,1,p.stdout+p.stderr)
            self.assertFalse((base/"escape.txt").exists())
            report=json.loads((out/"forensic-report.json").read_text())
            self.assertTrue(report["errors"])

if __name__=="__main__": unittest.main()
