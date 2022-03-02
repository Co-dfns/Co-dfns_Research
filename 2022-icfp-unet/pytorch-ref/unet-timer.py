import argparse
import pathlib
import random

import torch
import torch.nn
import torch.optim
import torch.utils.benchmark
import torchvision.io
import torchvision.transforms.functional

from unet import UNet


INPUTS = (pathlib.Path(__file__) / "../../Source/data/ISBI/images/").resolve()
LABELS = (pathlib.Path(__file__) / "../../Source/data/ISBI/labels/").resolve()
RUNS = 5


def run(unet, inp, expected_out, device, criterion, optimiser):
    """Trains the unet on a given input, label pair and returns computed output."""

    inp = inp.to(device)
    expected_out = expected_out.to(device)

    unet.zero_grad()
    out = unet(inp).softmax(dim=1)
    loss = criterion(out.softmax(dim=1), expected_out)
    loss.backward()
    optimiser.step()
    ret = out.to("cpu")  # Return the output to the CPU.
    return ret


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--inputs",
        metavar="INPUTS_PATH",
        help=f"Folder with input images (default={INPUTS})",
        default=INPUTS,
    )
    parser.add_argument(
        "-l",
        "--labels",
        metavar="LABELS_PATH",
        help=f"Folder with label images (default={LABELS})",
        default=LABELS,
    )
    parser.add_argument(
        "-n",
        help=f"Number of passes to time (default={RUNS})",
        default=RUNS,
        type=int,
    )
    parser.add_argument(
        "-d",
        "--device",
        help=f"Device to run on (default='cpu')",
        choices=["cpu", "cuda:0"],
        default="cpu",
    )
    parser.add_argument(
        "-t",
        "--num-threads",
        help=f"Number of CPU threads to use (default=1)",
        choices=["1", "max"],
        default="1",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        help="Produce verbose output",
        action="store_true",
    )
    args = parser.parse_args()
    # CPU single threads
    # Look at _aux.apln `Run`

    torch.set_default_dtype(torch.float64)  # Use 64 bit floats by default.

    inputs_available = list(pathlib.Path(args.inputs).glob("*"))
    inputs_to_use = random.choices(inputs_available, k=args.n)
    labels_to_use = [(LABELS / input.name).resolve() for input in inputs_to_use]

    # Pick correct device.
    device = args.device
    if device.startswith("cuda") and not torch.cuda.is_available():
        print("Forcing device='cpu'.")
        device = "cpu"

    num_threads = torch.get_num_threads() if args.num_threads == "max" else 1

    unet = UNet().to(device)
    criterion = torch.nn.CrossEntropyLoss()
    optimiser = torch.optim.SGD(unet.parameters(), lr=1e-9, momentum=0.99)

    for input_file, label_file in zip(inputs_to_use, labels_to_use):
        inp = (
            torchvision.io.read_image(
                str(input_file),
                mode=torchvision.io.ImageReadMode.GRAY,
            ).unsqueeze(0)
            / 256
        )

        size = inp.shape[-1] - 188  # Final size computation simplifies to this.
        expected_out = (
            torchvision.io.read_image(
                str(label_file),
                mode=torchvision.io.ImageReadMode.GRAY,
            )
            == 255
        ).long()
        expected_out = torchvision.transforms.functional.center_crop(
            expected_out, [size, size]
        )

        # PyTorch's Timer takes care of things like GPU sync.
        timer = torch.utils.benchmark.Timer(
            stmt="run(unet, inp, expected_out, device, criterion, optimiser)",
            setup="from __main__ import run",
            globals={
                "unet": unet,
                "inp": inp,
                "expected_out": expected_out,
                "device": device,
                "criterion": criterion,
                "optimiser": optimiser,
            },
            num_threads=num_threads,
        )
        measurement = timer.timeit(1)
        if args.verbose:
            print(measurement)
        else:
            print(measurement.mean)
