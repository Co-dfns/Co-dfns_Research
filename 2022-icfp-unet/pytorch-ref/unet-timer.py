import argparse
import pathlib
import random
import time

import torch
import torch.nn
import torch.optim
import torchvision.io
import torchvision.transforms.functional

from unet import UNet


INPUTS = (pathlib.Path(__file__) / "../../Source/data/ISBI/images/").resolve()
LABELS = (pathlib.Path(__file__) / "../../Source/data/ISBI/labels/").resolve()
RUNS = 5


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
    )
    parser.add_argument(
        "-d",
        "--device",
        help=f"Device to run on (default='cpu')",
        choices=["cpu", "cuda:0"],
        default="cpu",
    )
    args = parser.parse_args()

    torch.set_default_dtype(torch.float64)  # Use 64 bit floats by default.

    # Pick correct device.
    device = args.device
    if device.startswith("cuda") and not torch.cuda.is_available():
        print("Forcing device='cpu'.")
        device = "cpu"

    inputs_available = list(pathlib.Path(args.inputs).glob("*"))
    inputs_to_use = random.choices(inputs_available, k=args.n)
    labels_to_use = [(LABELS / input.name).resolve() for input in inputs_to_use]

    # Initialise model, optimiser and loss criterion.
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
        ).to(device)  # Use 64 bit floats.

        size = inp.shape[-1] - 188  # Final size computation simplifies to this.
        expected_out = (
            torchvision.io.read_image(
                str(label_file),
                mode=torchvision.io.ImageReadMode.GRAY,
            )
            == 255
        ).long().to(device)
        expected_out = torchvision.transforms.functional.center_crop(
            expected_out, [size, size]
        )

        start = time.perf_counter()
        unet.zero_grad()
        out = unet(inp)
        loss = criterion(out.softmax(dim=1), expected_out)
        loss.backward()
        optimiser.step()
        end = time.perf_counter()
        print(end - start)
