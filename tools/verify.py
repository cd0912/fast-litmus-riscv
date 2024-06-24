import subprocess

def execute_shell_command(cmd):
    # print(f'run cmd: {cmd}')
    try:
        result = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        # print("Standard Output:\n", result.stdout)
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)
    
    return str(result.stdout)

def run_herd_cmd(litmus_type, model_name, litmus_name):
    cmd =  f'herd7 -model ./model/riscv.cat -I ./model/{model_name}/ ./tests/{litmus_type}/{litmus_name}.litmus'
    return execute_shell_command(cmd)

if __name__ == "__main__":
    import sys
    assert len(sys.argv) == 3, "Usage: python3 verify.py [Type: allow|forbidden] [name]"
    litmus_type, litmus_name = sys.argv[1], sys.argv[2]
    litmus_name_2 = f'{litmus_name}_2'
    assert litmus_type in ['allow', 'forbidden'], "Type must be allow or forbidden"

    rvwmo_origin_output = run_herd_cmd(f'origin/{litmus_type}', 'rvwmo', litmus_name)
    rvwmo_unroll2_output = run_herd_cmd(f'unroll2/{litmus_type}', 'rvwmo', litmus_name_2)
    custom_origin_output = run_herd_cmd(f'origin/{litmus_type}', f'{litmus_type}/{litmus_name}', litmus_name)
    custom_unroll2_output = run_herd_cmd(f'unroll2/{litmus_type}', f'{litmus_type}/{litmus_name}', litmus_name_2)

    failed = False
    antonym = 'forbidden' if litmus_type == 'allow' else 'allowed'
    
    if 'Ok\n' not in rvwmo_origin_output:
        failed = True
        print(rvwmo_origin_output)
        print(f"FAIL: {litmus_type} test {litmus_name}.litmus should be {antonym} by RVWMO model")
        print("")

    if 'Ok\n' not in rvwmo_unroll2_output:
        failed = True
        print(rvwmo_unroll2_output)
        print(f"FAIL: {litmus_type} test {litmus_name_2}.litmus should be {antonym} by RVWMO model")
        print("")

    if 'No\n' not in custom_origin_output:
        failed = True
        print(custom_origin_output)
        print(f"FAIL: {litmus_type} test {litmus_name}.litmus should be {antonym} by {litmus_name} model")
        print("")

    if 'No\n' not in custom_unroll2_output:
        failed = True
        print(custom_unroll2_output)
        print(f"FAIL: {litmus_type} test {litmus_name_2}.litmus should be {antonym} by {litmus_name} model")
        print("")


    if not failed:
        print('PASS')
        