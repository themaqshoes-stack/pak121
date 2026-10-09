import argparse
from pathlib import Path

import cadquery as cq
import cv2
import numpy as np
from rembg import remove


def extract_contour(image: np.ndarray, clearance: int) -> np.ndarray:
    alpha = image[:, :, 3]
    _, binary = cv2.threshold(alpha, 127, 255, cv2.THRESH_BINARY)

    if clearance > 0:
        kernel_size = int(clearance * 2 + 1)
        kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE, (kernel_size, kernel_size)
        )
        binary = cv2.dilate(binary, kernel, iterations=1)

    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    largest_contour = max(contours, key=cv2.contourArea)

    return largest_contour


def create_3d(contour: np.ndarray, height: int) -> cq.Workplane:
    points = contour.squeeze()
    cq_points = [(float(point[0]), float(point[1])) for point in points]

    result = cq.Workplane("XY").polyline(cq_points).close().extrude(height)

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Generate 3D models (STL/STEP) from images"
    )
    parser.add_argument("input", help="Input image file path")
    parser.add_argument("--height", type=int, default=10, help="Height")
    parser.add_argument("--clearance", type=int, default=5, help="Clearance")

    args = parser.parse_args()
    input_path = Path(args.input)
    output_path = input_path.with_suffix(".step")

    print("=== Image to 3D Model Conversion ===")
    print(f"Input: {input_path}")
    print(f"Output: {output_path}")
    print(f"Height: {args.height}mm")
    print(f"Clearance: {args.clearance}px")
    print()

    # Step 1: Load image
    print("[1/5] Loading image...", end="", flush=True)
    if not input_path.exists():
        print(f"\nError: Input file not found: {input_path}")
        return
    input_image = cv2.imread(str(input_path))
    print("✓")

    # Step 2: Remove background
    print("[2/5] Removing background...", end="", flush=True)
    background_removed_image: np.ndarray = remove(input_image)  # type: ignore
    print(" ✓")

    # Step 3: Extract contour
    print("[3/5] Extracting contour...", end="", flush=True)
    contour = extract_contour(background_removed_image, args.clearance)
    print(" ✓")

    # Step 4: Create 3D model
    print("[4/5] Creating 3D model...", end="", flush=True)
    result = create_3d(contour, args.height)
    print(" ✓")

    # Step 5: Export to file
    print("[5/5] Exporting to STEP...", end="", flush=True)
    cq.exporters.export(
        result, str(output_path), exportType=cq.exporters.ExportTypes.STEP
    )
    print(" ✓")

    print()
    print("✅ Conversion completed successfully!")
    print(f"📁 Output saved to: {output_path}")


if __name__ == "__main__":
    main()
