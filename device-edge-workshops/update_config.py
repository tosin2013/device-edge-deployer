import yaml
import sys
import os
from colorama import Fore, Style, init

# Initialize Colorama for colored text
init(autoreset=True)

def read_yaml_file(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
    return data

def update_variable(variable_name, current_value):
    new_value = input(f"Enter a new value for '{Fore.BLUE}{variable_name}{Style.RESET_ALL}' (Press Enter to keep current value '{current_value}'): ")
    if new_value.strip() != "":
        return new_value
    else:
        return current_value

def update_variables(data):
    try:
        for key, value in data.items():
            if key == 'pull_secret' or key == 'base64_manifest':
                continue  # Skip the 'pull_secret' variable
            if isinstance(value, dict):
                update_variables(value)
            elif isinstance(value, str):
                data[key] = update_variable(key, value)
            elif isinstance(value, bool):
                new_value = input(f"Change value of '{Fore.BLUE}{key}{Style.RESET_ALL}' to True or False (Press Enter to keep current value '{value}'): ")
                if new_value.strip().lower() == 'true':
                    data[key] = True
                elif new_value.strip().lower() == 'false':
                    data[key] = False
                else:
                    print(f"Invalid input for '{key}', keeping current value '{value}'")

    except KeyboardInterrupt:
        print("\nExiting gracefully.")
        sys.exit(1)


def write_yaml_file(file_path, data):
    with open(file_path, 'w') as file:
        yaml.dump(data, file, default_flow_style=False)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file.yaml>")
        sys.exit(1)

    file_path = sys.argv[1]
    
    try:
        data = read_yaml_file(file_path)
        update_variables(data)
        
        # Prompt for the run_in_aws parameter
        new_run_in_aws = input("Do you want to deploy the lab in AWS (True/False) (Press Enter to keep current value): ")
        if new_run_in_aws.strip().lower() == 'true':
            data['run_in_aws'] = True
            aws_access_key_id = input("Enter AWS_ACCESS_KEY_ID: ")
            aws_secret_access_key = input("Enter AWS_SECRET_ACCESS_KEY: ")
            data['AWS_ACCESS_KEY_ID'] = aws_access_key_id
            data['AWS_SECRET_ACCESS_KEY'] = aws_secret_access_key
        elif new_run_in_aws.strip().lower() == 'false':
            data['run_in_aws'] = False
            # Clear AWS credentials if not deploying in AWS
            data['AWS_ACCESS_KEY_ID'] = ""
            data['AWS_SECRET_ACCESS_KEY'] = ""
        
        # Automatically read pull_secret and base64_manifest from the home directory
        home_dir = os.path.expanduser("~")
        pull_secret_file = os.path.join(home_dir, "pull-secret.json")
        base64_manifest_file = os.path.join(home_dir, "base64_platform_manifest.txt")
        
        if os.path.exists(pull_secret_file):
            with open(pull_secret_file, 'r') as pull_secret:
                data['pull_secret'] = pull_secret.read().strip()
        
        if os.path.exists(base64_manifest_file):
            with open(base64_manifest_file, 'r') as base64_manifest:
                data['base64_manifest'] = base64_manifest.read().strip()
        
        write_yaml_file(file_path, data)
        print(f"Config file '{file_path}' has been updated.")
    except FileNotFoundError:
        print(f"File '{file_path}' not found. Please provide a valid YAML config file.")
    except yaml.YAMLError:
        print(f"Error reading or writing to '{file_path}'. Please ensure it is a valid YAML file.")
