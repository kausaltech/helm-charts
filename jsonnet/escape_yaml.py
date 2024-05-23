import sys


def escape_yaml(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()

        content = (
            content.replace('{{', '{{`{{')
            .replace('}}', '}}`}}')
            .replace('{{`{{', '{{`{{`}}')
            .replace('}}`}}', '{{`}}`}}')
        )

        with open(file_path, 'w') as file:
            file.write(content)

        print(f'Processed (escaped) {file_path}')
    except Exception as e:
        print(f'Error processing {file_path}: {str(e)}')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('No files provided for escaping.')
        sys.exit(1)

    # Process each file passed as an argument
    for filepath in sys.argv[1:]:
        escape_yaml(filepath)
