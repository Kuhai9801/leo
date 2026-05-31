/*
Test that a fallible assertion after an early return is skipped when the return is taken.

[case]
program = "early_return_assert_probe.aleo"
function = "main"
input = ["true", "7u8"]

[case]
program = "early_return_assert_probe.aleo"
function = "main"
input = ["false", "7u8"]
*/

program early_return_assert_probe.aleo {
    fn main(flag: bool, x: u8) -> u8 {
        if flag {
            return 1u8;
        }

        assert(x / 0u8 == 1u8);
        return 2u8;
    }
}
