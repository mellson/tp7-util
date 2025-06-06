#!/usr/bin/env python3
"""
TP-7 Utility - Convert between TP-7 multitrack format and individual WAV files

The TP-7 stores 6 stereo tracks as a single 12-channel WAV file.
This utility can:
- Export: Split a 12-channel TP-7 WAV into 6 individual stereo WAV files
- Import: Combine up to 6 stereo WAV files into a single TP-7 compatible file
"""

import wave
import numpy as np
import argparse
import os
import sys
from pathlib import Path


def read_24bit_audio(audio_bytes):
    """Convert 24-bit audio bytes to 32-bit integers (vectorized)."""
    # Reshape to separate each 24-bit sample
    audio_bytes = audio_bytes.reshape(-1, 3)
    
    # Pad each 24-bit sample with a zero byte to make 32-bit
    padded = np.zeros((len(audio_bytes), 4), dtype=np.uint8)
    padded[:, :3] = audio_bytes
    
    # View as unsigned 32-bit little-endian integers first
    audio_32bit = padded.view('<u4').flatten()
    
    # Sign extend from 24-bit to 32-bit
    # If the 24th bit is set (0x00800000), we need to set the upper byte to 0xFF
    sign_bit_mask = (audio_32bit & 0x00800000) != 0
    audio_32bit = np.where(sign_bit_mask, 
                          audio_32bit | np.uint32(0xFF000000), 
                          audio_32bit).astype(np.int32)
    
    return audio_32bit


def write_24bit_audio(audio_array):
    """Convert 32-bit integer array to 24-bit audio bytes (vectorized)."""
    # Ensure we're working with 32-bit integers
    audio_array = audio_array.astype(np.int32)
    
    # View as bytes (little-endian)
    audio_bytes = audio_array.view(np.uint8).reshape(-1, 4)
    
    # Take only the first 3 bytes of each sample (little-endian = lower 3 bytes)
    output_bytes = audio_bytes[:, :3].flatten()
    
    return output_bytes


def export_multitrack(input_file, output_dir=None):
    """Export a TP-7 multitrack WAV file to individual stereo tracks."""
    
    input_path = Path(input_file)
    if not input_path.exists():
        print(f"Error: Input file '{input_file}' not found.")
        return False
    
    # Determine output directory
    if output_dir is None:
        output_dir = input_path.parent / f"{input_path.stem}_tracks"
    else:
        output_dir = Path(output_dir)
    
    output_dir.mkdir(exist_ok=True)
    
    try:
        with wave.open(str(input_path), 'rb') as wav_in:
            # Verify it's a 12-channel file
            channels = wav_in.getnchannels()
            if channels != 12:
                print(f"Error: Expected 12 channels, but found {channels}.")
                print("This doesn't appear to be a TP-7 multitrack file.")
                return False
            
            # Get audio parameters
            params = wav_in.getparams()
            sample_width = params.sampwidth
            framerate = params.framerate
            n_frames = params.nframes
            
            print(f"Input file: {input_file}")
            print(f"Format: {channels} channels, {sample_width*8}-bit, {framerate} Hz")
            print(f"Duration: {n_frames/framerate:.2f} seconds")
            print(f"Output directory: {output_dir}")
            
            # Read all audio data
            print("\nReading audio data...")
            audio_data = wav_in.readframes(n_frames)
            
            # Convert to numpy array
            if sample_width == 2:
                audio_array = np.frombuffer(audio_data, dtype=np.int16)
            elif sample_width == 3:
                audio_array = read_24bit_audio(np.frombuffer(audio_data, dtype=np.uint8))
            elif sample_width == 4:
                audio_array = np.frombuffer(audio_data, dtype=np.int32)
            else:
                print(f"Error: Unsupported sample width: {sample_width}")
                return False
            
            # Reshape to separate channels
            audio_array = audio_array.reshape(n_frames, channels)
            
            # Split into 6 stereo tracks
            for track_num in range(6):
                left_channel = track_num * 2
                right_channel = track_num * 2 + 1
                
                stereo_data = audio_array[:, [left_channel, right_channel]]
                
                # Output filename
                output_file = output_dir / f"track_{track_num + 1:02d}.wav"
                
                print(f"Exporting track {track_num + 1} to {output_file.name}...")
                
                # Write stereo WAV file
                with wave.open(str(output_file), 'wb') as wav_out:
                    wav_out.setnchannels(2)  # Stereo
                    wav_out.setsampwidth(sample_width)
                    wav_out.setframerate(framerate)
                    
                    # Convert back to bytes
                    if sample_width == 2:
                        wav_out.writeframes(stereo_data.astype(np.int16).tobytes())
                    elif sample_width == 3:
                        stereo_bytes = write_24bit_audio(stereo_data.flatten())
                        wav_out.writeframes(stereo_bytes.tobytes())
                    elif sample_width == 4:
                        wav_out.writeframes(stereo_data.astype(np.int32).tobytes())
            
            print(f"\nSuccessfully exported 6 stereo tracks to {output_dir}")
            return True
            
    except Exception as e:
        print(f"Error processing file: {e}")
        import traceback
        traceback.print_exc()
        return False


def import_to_multitrack(input_files, output_file):
    """Import stereo WAV files and combine them into a TP-7 multitrack format."""
    
    # Ensure we have a list of files
    if isinstance(input_files, str):
        input_files = [input_files]
    
    # Validate input files
    valid_files = []
    for f in input_files:
        if Path(f).exists():
            valid_files.append(f)
        else:
            print(f"Warning: File '{f}' not found, skipping.")
    
    if not valid_files:
        print("Error: No valid input files found.")
        return False
    
    if len(valid_files) > 6:
        print("Error: TP-7 supports maximum 6 stereo tracks.")
        return False
    
    print(f"Found {len(valid_files)} valid input file(s)")
    
    # Read first file to get reference parameters
    with wave.open(valid_files[0], 'rb') as wav_ref:
        ref_params = wav_ref.getparams()
        ref_channels = ref_params.nchannels
        ref_width = ref_params.sampwidth
        ref_rate = ref_params.framerate
        ref_frames = ref_params.nframes
    
    if ref_channels != 2:
        print(f"Error: First file must be stereo (found {ref_channels} channels)")
        return False
    
    print(f"Reference format: {ref_width*8}-bit, {ref_rate} Hz, {ref_frames} frames")
    
    # Prepare arrays for all tracks
    all_tracks = []
    
    # Load all input files
    for i, input_file in enumerate(valid_files):
        print(f"Loading track {i+1}: {Path(input_file).name}")
        
        with wave.open(input_file, 'rb') as wav_in:
            params = wav_in.getparams()
            
            # Verify format matches
            if params.nchannels != 2:
                print(f"Error: File must be stereo (found {params.nchannels} channels)")
                return False
            
            if params.sampwidth != ref_width:
                print(f"Error: Sample width mismatch ({params.sampwidth} vs {ref_width})")
                return False
                
            if params.framerate != ref_rate:
                print(f"Error: Sample rate mismatch ({params.framerate} vs {ref_rate})")
                return False
            
            # Read audio data
            audio_data = wav_in.readframes(params.nframes)
            
            # Convert to numpy array
            if ref_width == 2:
                audio_array = np.frombuffer(audio_data, dtype=np.int16)
            elif ref_width == 3:
                audio_array = read_24bit_audio(np.frombuffer(audio_data, dtype=np.uint8))
            elif ref_width == 4:
                audio_array = np.frombuffer(audio_data, dtype=np.int32)
            else:
                print(f"Error: Unsupported sample width: {ref_width}")
                return False
            
            audio_array = audio_array.reshape(-1, 2)
            all_tracks.append(audio_array)
    
    # Find the length of the longest track
    max_frames = max(track.shape[0] for track in all_tracks)
    print(f"\nMax track length: {max_frames} frames ({max_frames/ref_rate:.2f} seconds)")
    
    # Create 12-channel array (6 stereo tracks)
    if ref_width == 2:
        dtype = np.int16
    else:
        dtype = np.int32
    
    multitrack = np.zeros((max_frames, 12), dtype=dtype)
    
    # Fill in the tracks we have
    for i, track in enumerate(all_tracks):
        track_frames = track.shape[0]
        multitrack[:track_frames, i*2:i*2+2] = track
        
        # Pad with silence if needed
        if track_frames < max_frames:
            print(f"Track {i+1}: Padding {max_frames - track_frames} frames with silence")
    
    # Fill remaining tracks with silence (they're already zeros)
    for i in range(len(all_tracks), 6):
        print(f"Track {i+1}: Empty (silence)")
    
    # Write output file
    print(f"\nWriting TP-7 multitrack file: {output_file}")
    
    with wave.open(output_file, 'wb') as wav_out:
        wav_out.setnchannels(12)  # 6 stereo tracks = 12 channels
        wav_out.setsampwidth(ref_width)
        wav_out.setframerate(ref_rate)
        
        # Convert back to bytes
        if ref_width == 2:
            wav_out.writeframes(multitrack.astype(np.int16).tobytes())
        elif ref_width == 3:
            multitrack_bytes = write_24bit_audio(multitrack.flatten())
            wav_out.writeframes(multitrack_bytes.tobytes())
        elif ref_width == 4:
            wav_out.writeframes(multitrack.astype(np.int32).tobytes())
    
    print(f"Successfully created TP-7 multitrack file with {len(valid_files)} active tracks")
    return True


def main():
    parser = argparse.ArgumentParser(
        description='TP-7 Utility - Convert between TP-7 multitrack format and individual WAV files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Export multitrack to individual files:
    tp7-util export recording.WAV
    tp7-util export recording.WAV -o ./tracks/
    
  Import stereo files to multitrack:
    tp7-util import track1.wav -o multitrack.WAV
    tp7-util import track1.wav track2.wav track3.wav -o multitrack.WAV
    tp7-util import *.wav -o multitrack.WAV
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Export command
    export_parser = subparsers.add_parser('export', help='Export multitrack to individual stereo files')
    export_parser.add_argument('input', help='TP-7 multitrack WAV file')
    export_parser.add_argument('-o', '--output', help='Output directory (default: <input>_tracks/)')
    
    # Import command
    import_parser = subparsers.add_parser('import', help='Import stereo files to TP-7 multitrack format')
    import_parser.add_argument('inputs', nargs='+', help='Stereo WAV files to import (max 6)')
    import_parser.add_argument('-o', '--output', required=True, help='Output TP-7 multitrack WAV file')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    if args.command == 'export':
        success = export_multitrack(args.input, args.output)
        sys.exit(0 if success else 1)
    
    elif args.command == 'import':
        success = import_to_multitrack(args.inputs, args.output)
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()