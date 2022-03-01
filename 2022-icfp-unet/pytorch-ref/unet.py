import torch
import torch.nn as nn
import torchvision
import torchvision.transforms.functional


class TwoConv(nn.Module):
    """Represents the application of two convolutions followed by ReLUs.

    This module is used in the contracting and expanding paths of the u-net architecture.
    Each convolution is a 3 by 3 convolution with no padding and stride of 1;
    we also use no bias.
    Each convolution is followed by a ReLU.
    """

    def __init__(self, in_channels, out_channels):
        super().__init__()

        self.path = nn.Sequential(
            nn.Conv2d(in_channels, out_channels, kernel_size=(3, 3), bias=False),
            nn.ReLU(inplace=True),
            nn.Conv2d(out_channels, out_channels, kernel_size=(3, 3), bias=False),
            nn.ReLU(inplace=True),
        )

    def forward(self, x):
        return self.path(x)


class Down(nn.Module):
    """Represents the "down" step of the u-net architecture.

    This "down" step, represented on the left of Figure 1 in the original paper,
    consists of 2x2 max pooling followed by a TwoConv module.
    The number of channels of the output is double the number of channels of the input.
    """

    def __init__(self, in_channels):
        super().__init__()

        self.path = nn.Sequential(
            nn.MaxPool2d(kernel_size=(2, 2), stride=2),
            TwoConv(in_channels, 2 * in_channels),
        )

    def forward(self, x):
        return self.path(x)


class Up(nn.Module):
    """Represents the "up" step of the u-net architecture.

    This "up" step, represented on the right of Figure 1 in the original paper,
    consists of upsampling by means of a transposed convolution with stride 2,
    followed by a TwoConv module that halves the number of channels.

    In its forward pass, `forward` expects two inputs: the first corresponds to the input
    that was coppied from "across" the U shape and needs to be cropped while the second
    corresponds to the regular output of the network path.
    """

    def __init__(self, in_channels):
        super().__init__()

        self.upsampling = nn.ConvTranspose2d(
            in_channels,
            in_channels // 2,
            kernel_size=(2, 2),
            stride=2,
            bias=False,
        )
        self.convolutions = TwoConv(in_channels, in_channels // 2)

    def forward(self, x_to_crop, x_in):
        """Performs the forward pass by taking into account the cropped channels."""

        upped = self.upsampling(x_in)
        cropped = torchvision.transforms.functional.center_crop(
            x_to_crop, upped.shape[-2:]
        )
        x = torch.cat([cropped, upped], dim=1)
        return self.convolutions(x)


class USegment(nn.Module):
    """Represents an anti-simmetric segment of the U in the u-net architecture.

    This module represents part of the contracting path together with the corresponding
    expansive path, in such a way that the output of the down portion represented gets
    copied into the input of the expansive path, to act as the portion that needs to be
    cropped.

    By using these segments, the u-net architecture can be built from the bottom up."""

    def __init__(self, in_channels, bottom_u=None):
        super().__init__()

        # Default value for the bottom U.
        if bottom_u is None:
            bottom_u = lambda x: x

        self.down = Down(in_channels)
        self.bottom_u = bottom_u
        self.up = Up(2 * in_channels)

    def forward(self, x):
        return self.up(x, self.bottom_u(self.down(x)))


class UNet(nn.Module):
    """Represents the u-net architecture."""

    def __init__(self):
        super().__init__()

        self.u = USegment(512)
        self.u = USegment(256, self.u)
        self.u = USegment(128, self.u)
        self.u = USegment(64, self.u)
        self.path = nn.Sequential(
            TwoConv(1, 64),
            self.u,
            nn.Conv2d(64, 2, kernel_size=1, bias=False),
        )

    def forward(self, x):
        return self.path(x)


if __name__ == "__main__":
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    print(device)

    unet = UNet()
    unet.to(device)
    inp = torch.randn((1, 1, 572, 572)).to(device)
    out = unet(inp)
    assert out.shape == torch.Size([1, 2, 388, 388])

    expected_out = 0 * torch.randn((1, 2, 4, 4)).to(device)
    criterion = nn.MSELoss()

    print("First pass on test data:")
    test_inp = [torch.randn((1, 1, 188, 188)).to(device) for _ in range(100)]
    error = 0
    for inp in test_inp:
        out = unet(inp)
        error += criterion(out, expected_out)
    print(error)

    import torch.optim

    optimiser = torch.optim.SGD(unet.parameters(), lr=0.01, momentum=0.9)

    print("Training:")
    for _ in range(100):
        optimiser.zero_grad()
        inp = torch.randn((1, 1, 188, 188)).to(device)
        out = unet(inp)
        loss = criterion(out, expected_out)
        loss.backward()
        optimiser.step()

    print("Second pass on test data:")
    error = 0
    for inp in test_inp:
        out = unet(inp)
        error += criterion(out, expected_out)
    print(error)
