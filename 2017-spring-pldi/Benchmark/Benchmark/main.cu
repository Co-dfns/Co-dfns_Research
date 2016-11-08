#include <algorithm>
#include <chrono>
#include <cmath>
#include <ctime>
#include <iostream>
#include <string>
#include <vector>

#include <thrust/host_vector.h>
#include <thrust/device_vector.h>

using namespace std;

struct CPUNode {
	long long id;
	short type;
	vector<CPUNode> kids;
	CPUNode();
	CPUNode(int depth, int width, int& id);
	CPUNode(long long id, short type, vector<CPUNode> kids);
	friend ostream& operator<<(ostream& os, const CPUNode& node);
};

CPUNode::CPUNode()
	: id(0),type(1),kids(vector<CPUNode>())
{}

CPUNode::CPUNode(int depth, int width, int& id)
	: id(id++)
{
	if (depth) {
		type = 0;
		kids = vector<CPUNode>(width);
		for (CPUNode& node : kids)
			node = CPUNode(depth - 1, width, id);
	} else {
		type = 1;
		kids = vector<CPUNode>();
	}
}

CPUNode::CPUNode(long long id, short type, vector<CPUNode> kids)
	: id(id),type(type),kids(kids)
{}

ostream& operator<<(ostream& os, const CPUNode& node)
{
	os << node.type << " " << node.id;
	return os;
}

void print_tree(CPUNode& node, int depth)
{
	for (int i = 0; i < depth; i++)
		cout << " ";

	cout << node << endl;

	for (CPUNode& kid : node.kids)
		print_tree(kid, depth + 1);
}

void help(void) 
{
	cout << "Benchmark <cpu|gpu> <print|quiet> [<depth> <width>]" << endl;
}

void cpu_flatten_helper(CPUNode& node, vector<CPUNode>& lifted)
{
	if (!node.type) {
		for_each(node.kids.rbegin(), node.kids.rend(), [&lifted](CPUNode& kid) {
			cpu_flatten_helper(kid, lifted);
		});

		lifted.push_back(node);
		node.type = 1;
		node.kids = vector<CPUNode>();
	}
}

void cpu_flatten(CPUNode& node)
{
	vector<CPUNode> lifted;

	cpu_flatten_helper(node, lifted);

	node = CPUNode{ -1, 0, lifted };
}

void benchmark_cpu(int depth, int width, bool print)
{
	cout << "Benchmarking CPU algorithm (Depth: " << depth << " Width: " << width << ")" << endl;

	cout << "Creating AST...";

	int id = 0;
	CPUNode node(depth, width, id);

	cout << "done." << endl;

	if (print) {
		cout << endl << "Before: " << endl;
		print_tree(node, 1);
		cout << endl;
	}

	cout << "Flattening AST...";

	auto start = chrono::high_resolution_clock::now();
	cpu_flatten(node);
	auto end = chrono::high_resolution_clock::now();

	cout << "took " << chrono::duration_cast<chrono::milliseconds>(end - start).count()
		<< " milliseconds." << endl;

	if (print) {
		cout << endl << "After: " << endl;
		print_tree(node, 1);
	}
}

void benchmark_gpu(int depth, int width, bool print)
{
	cout << "Benchmarking GPU algorithm (Depth: " << depth << " Width: " << width << ")..." << endl;
}

int main(int argc, char *argv[])
{
	int depth = 3;
	int width = 2;
	bool print = true;

	string print_str("print");
	string quiet_str("quiet");
	string cpu_str("cpu");
	string gpu_str("gpu");

	if (argc != 3 && argc != 5) {
		help();
		return 1;
	}

	if (argc == 5) {
		depth = stoi(argv[3]);
		width = stoi(argv[4]);
	}

	if (print_str == argv[2])
		print = true;
	else if (quiet_str == argv[2])
		print = false;
	else {
		help();
		return 1;
	}

	if (cpu_str == argv[1])
		benchmark_cpu(depth, width, print);
	else if (gpu_str == argv[1])
		benchmark_gpu(depth, width, print);
	else {
		help();
		return 1;
	}

	return 0;
}