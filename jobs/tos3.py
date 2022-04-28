import os

from minio import Minio
from minio.error import S3Error
import click


@click.command()
@click.argument("filename")
@click.option("--host")
@click.option("--bucket")
@click.option("--id")
@click.option("--secret")
def tos3(filename, host, bucket, id, secret):
    """simple s3/objectstore uploader"""
    client = Minio(
        host,
        access_key=id,
        secret_key=secret,
    )
    client.fput_object(
        bucket,
        filename,
        filename,
        metadata={'x-amz-acl': 'public-read'}
     )

if __name__ == "__main__":
    try:
        tos3(auto_envvar_prefix="OBJECTSTORE")
    except S3Error as exc:
        click.echo("error occurred.", exc)
