/*
Test that an inclusive loop with equal start and stop executes once.

[case]
program = "inclusive_loop_singleton_probe.aleo"
function = "main"
input = []
*/

program inclusive_loop_singleton_probe.aleo {
    fn main() -> u8 {
        let sum: u8 = 0u8;
        for i: u8 in 3u8..=3u8 {
            sum += 1u8;
        }
        return sum;
    }
}
