/*
Test that assertions over an array see prior element writes.

[case]
program = "assert_after_array_write_probe.aleo"
function = "main"
input = []
*/

program assert_after_array_write_probe.aleo {
    fn main() -> u8 {
        let xs: [u8; 2] = [0u8, 0u8];
        xs[0u32] = 5u8;
        assert_eq(xs, [0u8, 0u8]);
        return 1u8;
    }
}
