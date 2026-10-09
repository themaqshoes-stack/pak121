# Image to STEP Converter

A simple tool that converts images to 3D STEP models. Aimed at creating Gridfinity bin customization parts.

## Features

- Automatic background removal
- Adjustable height and clearance for perfect fit
- Exports to STEP format for easy CAD modification
- 📐 Contour extraction with adjustable clearance
- 🔧 Direct STEP file output for CAD compatibility
- 📊 Real-time progress feedback

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/image_to_step.git
cd image_to_step

# Install dependencies with uv
uv sync
```

## Usage

```bash
# Basic usage
uv run python image_to_step.py your_image.png

# With custom parameters
uv run python image_to_step.py your_image.png --height 20 --clearance 10
```

### Parameters

- `input`: Input image file path (required)
- `--height`: Model height (default: 10)
- `--clearance`: Clearance in pixels (default: 5)

## Example

```bash
$ uv run python simple_image_to_step.py caliper.jpg --height 15
=== Image to 3D Model Converter ===
Input: caliper.jpg
Output: caliper.step
Height: 15
Clearance: 5

[1/5] Loading image...✓
[2/5] Removing background... ✓
[3/5] Extracting contour... ✓
[4/5] Creating 3D model... ✓
[5/5] Exporting to STEP... ✓

✅ Conversion completed successfully!
📁 Output saved to: caliper.step
```
