import unittest
import icon/rle

suite "RLE":
    test "pack Bits Normaly":
        const src = @[
            0xaa,
            0xaa,
            0xaa,
            0x80,
            0x00,
            0x2a,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0x80,
            0x00,
            0x2a,
            0x22,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0xaa,
            0xaa
        ]
        const expected = @[
            0xfe,
            0xaa,
            0x02,
            0x80,
            0x00,
            0x2a,
            0xfd,
            0xaa,
            0x03,
            0x80,
            0x00,
            0x2a,
            0x22,
            0xf7,
            0xaa
        ]

        let actual = packBits(src)
        check actual == expected

    test "packICNS Normaly":
        const src = @[0, 0, 0, 249, 250, 128, 100, 101]
        const actual = packICNS(src)
        const expected = @[128, 0, 4, 249, 250, 128, 100, 101]
        check actual == expected