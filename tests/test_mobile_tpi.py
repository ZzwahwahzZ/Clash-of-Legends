import struct, tempfile, unittest, zlib
from pathlib import Path
from tools.asset_forensics.extract_mobile_tpi import MAGIC, HEADER_SIZE, parse_tpi, run

class MobileTpiExtractorTests(unittest.TestCase):
    def test_extracts_plain_and_deflated_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            payloads=[("ui/icon.mjp",b"MJPsample-data"),("models/test.c3",b"C3"+bytes(range(32)))]
            blobs=[]; records=[]
            offset=0
            for name,raw in payloads:
                packed=zlib.compress(raw) if name.endswith(".mjp") else raw
                blobs.append(packed)
                n=name.encode("cp1252")
                records.append(bytes([len(n)])+n+b"\0\0"+struct.pack("<IIIII",len(raw),len(packed),len(packed),len(raw),offset))
                offset+=len(packed)
            tpi=root/"data.tpi"; tpd=root/"data.tpd"
            header=bytearray(HEADER_SIZE)
            header[:len(MAGIC)]=MAGIC
            struct.pack_into("<I",header,0x24,len(records))
            tpi.write_bytes(bytes(header)+b"".join(records))
            tpd.write_bytes(b"".join(blobs))
            entries,errors=parse_tpi(tpi,tpd)
            self.assertEqual(errors,[])
            self.assertEqual([e["data"] for e in entries],[p[1] for p in payloads])
            report=run(root,root/"out")
            self.assertEqual(report["extracted_count"],2)
            self.assertEqual((root/"out/data/ui/icon.mjp").read_bytes(),payloads[0][1])

if __name__=="__main__":
    unittest.main()
