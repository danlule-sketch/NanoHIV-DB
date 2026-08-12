#!/usr/bin/env python3

'''
Short Python script to read in a tree file and save it as a pdf. Also has the option to rerot the tree first using RAxML. 
'''
__author__ = "Samantha Campbell"

import re 
import argparse
import subprocess as sp
from ete3 import Tree, TreeStyle, NodeStyle, TextFace

parser = argparse.ArgumentParser()
parser.add_argument('--tree', required=True, help='Requires tree from RaxML')
parser.add_argument('--reroot', required=False, action='store_true', help='If true, the tree will be rerooted at the branch that best balances the subtree lengths by RAxML. Default = False')
args=parser.parse_args()

tree_in = ""
reroot=False

if args.tree:
    tree_in = args.tree
else:
    print ("Tree required!")

if args.reroot:
    reroot=True


refSeqs = set(['A1', 'A2', 'AE', 'AG', 'B1', 'B2', 'C1', 'C2', 'D1', 'D2', 'F1', 'G1', 'G2', 'H', 'J', 'K'])

t = ''
if reroot == True:
    print ("Running RAxML to reroot " + tree_in + "\n")
    raxml_command = 'raxmlHPC -f I -m GTRGAMMA --JC69 -t ' + tree_in + ' -n visual'
    rooted_tree = sp.run(raxml_command, shell=True, check=True)
    
    new_tree = "RAxML_rootedTree.visual"

    print ("Rerooted tree saved as: " + new_tree + "\n")

    nw = re.sub(":(\d+\.\d+)\[(\d+)\]", ":\\1[&&NHX:support=\\2]", open(new_tree).read())
    t = Tree(nw, quoted_node_names=True, format=1)
else:
    t = Tree(tree_in)

ts = TreeStyle()
ts.show_branch_support = True
ts.show_leaf_name=False

nstyle = NodeStyle()
nstyle["size"] = 0
nstyle["fgcolor"] = 'black'

nstyle["vt_line_width"] = 1
nstyle["hz_line_width"] = 1
nstyle["vt_line_type"] = 0 # 0 solid, 1 dashed, 2 dotted
nstyle["hz_line_type"] = 0
t.set_style(nstyle)

print ("Formatting tree...")


for n in t.traverse():
    if n.is_leaf():
        if n.name in refSeqs:
            name_face = TextFace(n.name, fgcolor="blue", fsize=6)
            n.add_face(name_face, column=0, position='branch-right')
            n.set_style(nstyle)
        else:
            name_face = TextFace(n.name, fgcolor="red", fsize=6)
            n.add_face(name_face, column=0, position='branch-right')
            n.set_style(nstyle)
    else:
         n.set_style(nstyle)

t.set_style(nstyle)
tree_out = "RAxML_tree-rerooted.pdf"
t.render(tree_out, w=183, units="mm", tree_style = ts)

print ("Tree saved to " + tree_out)
