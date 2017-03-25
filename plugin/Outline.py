import vim
import ast
import sys

python_buf = int(vim.eval("g:pystuff#python_buf"))
outline_buf = int(vim.eval("g:pystuff#outline_buf"))
code = "\n".join(vim.buffers[python_buf][:])

vim.command("sp|" + str(outline_buf) + "b!|setlocal modifiable modified noreadonly")

del vim.current.buffer[:]

try:
    tree = ast.parse(code)
    def generate_info(tree):
        result = []
        for thing in tree.body:
            to_write = ()
            if isinstance(thing, ast.If):
                result.extend(generate_info(thing))
                a = ast.Module()
                a.body = thing.orelse
                result.extend(generate_info(a))
            if isinstance(thing, ast.FunctionDef):
                to_write = ("def", thing.name, generate_info(thing))
            if isinstance(thing, ast.Assign):
                target_names = [
                        target.id if isinstance(target, ast.Name) else
                        target.value.id + "." + target.attr
                        for target in thing.targets if isinstance(target, ast.Name) or isinstance(target, ast.Attribute)]
                if target_names:
                    to_write = ("=", target_names)
            if isinstance(thing, ast.ClassDef):
                to_write = ("class", thing.name, generate_info(thing))
            if to_write != ():
                result.append((thing, to_write))

        return result

    def get_args_pretty(function):
        args = function.args.args
        return ", ".join([arg.arg for arg in args])

    def pretty(generated_infos, indent=0):
        total = ""
        for generated_info in generated_infos:
            thing, info = generated_info
            
            info_type = info[0]

            res = "???"
            if info_type == "def":
                res = "def " + info[1] + "(%s)\n" % (get_args_pretty(thing))
                res += pretty(info[2], indent + 1)
            if info_type == "=":
                variables = info[1]
                res = "* " + ", ".join(variables)
            if info_type == "class":
                res = "class " + info[1] + "\n"
                res += pretty(info[2], indent + 1)

            total += str(thing.lineno) + ": " + res + "\n"
        return "\n".join("  " * indent + line for line in total.split("\n") if line.strip() != "")

    p = pretty(generate_info(tree))
     
    vim.current.buffer.append(p.split("\n"))
    vim.command("set syntax=python")

except SyntaxError as e:
    vim.current.buffer.append("%s: %s line %s" % (e.msg, repr(e.text.strip()), e.lineno))
    vim.command("set syntax=")

del vim.current.buffer[0] # Remove leading newline
vim.command("setlocal nomodifiable nomodified readonly|q!")

