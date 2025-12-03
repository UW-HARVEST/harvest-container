#!/usr/bin/python3
import logging
import os
import subprocess
import sys
import tarfile
from pathlib import Path
from tempfile import TemporaryDirectory

import boto3
from botocore.exceptions import ClientError, NoCredentialsError, NoRegionError


logging.basicConfig(level=os.environ.get("LOG_LEVEL", default="INFO"))


def _safe_extract(tar: tarfile.TarFile, dest: Path) -> None:
    members = tar.getmembers()
    for m in members:
        p = Path(m.name)
        if p.is_absolute() or ".." in p.parts:
            raise ValueError(f"Unsafe tar entry: {m.name}")
    tar.extractall(dest, members=members)

def run_translation(test_case_tar: Path, output_tar: Path) -> None:
    gz = Path(output_tar).suffixes[-2:] == [".tar", ".gz"] or output_tar.suffix == ".tgz"
    out_mode = "w:gz" if gz else "w"

    
    with TemporaryDirectory() as tmpdir_str, TemporaryDirectory() as outdir_str:
        # Get the name of the test case to use as base input directory
        # Assumes `test_case_tar` is like "example.tar.gz" -> "example"
        test_case = test_case_tar.name.split(".", 1)[0]

        # Use the test case name as the name of the directory to ensure CMakeLists.txt containing 
        # the variable ${project_name} keeps the project name consistent with C
        tmpdir = Path(f"{tmpdir_str}/{test_case}/test_case")
        os.makedirs(tmpdir)
        outdir = Path(outdir_str)
        
        with tarfile.open(test_case_tar, "r:*") as tar_in:
            _safe_extract(tar_in, tmpdir)

        # -------------------------------------------
        # REPLACE THIS WITH YOUR TRANSLATION PROCESS
        # -------------------------------------------
        demo_cmd = ["translate", str(tmpdir), str(outdir)]
        # demo_cmd = ["/usr/c2rust_execution/c2rust_commands.sh", str(tmpdir), str(outdir)]
        # demo_cmd = [Path(os.getcwd()).joinpath("c2rust_commands.sh"), str(tmpdir), str(outdir)]

        stdout_log = outdir / "stdout.log"
        stderr_log = outdir / "stderr.log"

        env = os.environ.copy()
        # If you need to modify the env for your tool
        env.update({"newuid": str(os.getuid()), "newgid": str(os.getgid())})

        completed = None
        try:
            with stdout_log.open("w", encoding="utf-8") as out_f, stderr_log.open("w", encoding="utf-8") as err_f:
                completed = subprocess.run(
                    demo_cmd,      # Swap to real_cmd
                    cwd=tmpdir,
                    env=env,
                    stdout=out_f,
                    stderr=err_f,
                    text=True,
                    check=False,
                )
        except Exception as e:
            # Cannot start the program. This is catestrophic enough that we'll just abort ASAP.
            # There will be _no_ tarfile [containing a stderr.log]
            raise RuntimeError(f"Execution of tool failed") from e
        
        if completed is None or completed.returncode != 0:
            # Program started but did not complete successfully.
            # Don't raise exception here. We want to still create a tarfile [containing the stderr.log]
            logging.warning(
                f"Tool failed with exit code {completed.returncode}. "
                f"See {stdout_log} and {stderr_log} for more detailed logging."
            )

        print(f"Completed translation")

        print(f"Tarfile: {output_tar} with mode {out_mode}")
        try: 
            with tarfile.open(output_tar, out_mode) as tar_out:
                for p in outdir.rglob("*"):
                    if p.is_file():
                        print(f"Adding {p} to tar archive")
                        tar_out.add(p, arcname=p.relative_to(outdir).as_posix())
        except Exception as e:
            raise RuntimeError(f"Failed to create tar archive") from e

def main() -> int: 
    # Retrieve the environment variables
    s3_input_bucket = os.environ.get("S3_INPUT_BUCKET", "tractor-input-bucket")
    s3_output_bucket = os.environ.get("S3_OUTPUT_BUCKET", "c2rust-output-bucket")
    translated_rust = os.environ.get("TRANSLATED_RUST", "/tmp/out/translated_rust.tar.gz")
    # e.g., Public-Tests/B01_organic/bin2hex_lib.tar.gz
    s3_key = os.environ.get("S3_KEY")

    if not s3_key:
        print("S3_KEY environment variable not set.", file=sys.stderr)
        return 1

    # For destination, don't write to /tmp/in/test_case.tar.gz
    # Instead, write to               /tmp/in/bin2hex_lib.tar.gz
    the_name = os.path.basename(s3_key)  # e.g., bin2hex_lib.tar.gz
    test_case = os.environ.get("TEST_CASE", f"/tmp/in/{the_name}")

    input_key = f"input/{s3_key}"
    output_key = f"output/{s3_key}"
    
    # Initialize S3 client using credentials from the environment
    try:
        s3 = boto3.client('s3')
    except (NoRegionError, NoCredentialsError) as e:
        logging.exception("AWS configuration error")
        return 1

    # -------------------------------------------
    # Download
    # -------------------------------------------
    Path(test_case).parent.mkdir(parents=True, exist_ok=True)
    Path(translated_rust).parent.mkdir(parents=True, exist_ok=True)

    try:
        s3.download_file(s3_input_bucket, input_key, str(test_case))
    except ClientError as e:
        logging.exception(f"Error downloading '{input_key}' from bucket '{s3_input_bucket}'")
        return 1

    print(f"Downloaded 's3://{s3_input_bucket}/{input_key}' -> '{test_case}'")

    # -------------------------------------------
    # Translate
    # -------------------------------------------   
    try:
        run_translation(Path(test_case), Path(translated_rust))
    except Exception as e:
        logging.exception(f"Translation step failed")
        return 1
    print(f"Created output archive at '{translated_rust}'")

    # -------------------------------------------
    # Upload
    # -------------------------------------------     
    try:
        s3.upload_file(str(translated_rust), s3_output_bucket, output_key)
    except ClientError as e:
        logging.exception(f"Error uploading to '{output_key}' in bucket '{s3_output_bucket}'")
        return 1

    print(f"Uploaded '{translated_rust}' -> 's3://{s3_output_bucket}/{output_key}'")

    return 0

if __name__ == "__main__":
    exit(main())
