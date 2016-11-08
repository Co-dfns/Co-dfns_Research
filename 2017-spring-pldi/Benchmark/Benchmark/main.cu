#include <algorithm>
#include <chrono>
#include <cmath>
#include <ctime>
#include <iostream>
#include <string>
#include <vector>

#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/for_each.h>
#include <thrust/iterator/zip_iterator.h>
#include <thrust/sequence.h>

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

void print_cpu_tree(CPUNode& node, int depth)
{
	for (int i = 0; i < depth; i++)
		cout << " ";

	cout << node << endl;

	for (CPUNode& kid : node.kids)
		print_cpu_tree(kid, depth + 1);
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
		print_cpu_tree(node, 1);
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
		print_cpu_tree(node, 1);
	}
}

struct print_gpu_node {
	template <typename Tuple>
	__host__
	void operator()(Tuple t) 
	{
		for (int i = 0; i <= thrust::get<1>(t); i++)
			cout << " ";

		cout << thrust::get<2>(t) << " " << thrust::get<0>(t) << " ";

		for (int v : thrust::get<3>(t))
			cout << " " << v;

		cout << endl;
	}
};

void print_gpu_tree(thrust::host_vector<int> depths,
	thrust::host_vector<long long> ids,
	thrust::host_vector<short> types,
	thrust::host_vector<vector<int>> coords)
{
	thrust::for_each(thrust::make_zip_iterator(thrust::make_tuple(ids.begin(), depths.begin(), types.begin(), coords.begin())),
		thrust::make_zip_iterator(thrust::make_tuple(ids.end(), depths.end(), types.end(), coords.end())),
		print_gpu_node());
}

void benchmark_gpu(int depth, int width, bool print)
{
	cout << "Benchmarking GPU algorithm (Depth: " << depth << " Width: " << width << ")..." << endl;
	cout << "Creating AST...";

	long long count = 0;

	for (int i = 0; i <= depth; i++) {
		count += pow(width, i);
	}

	thrust::host_vector<int> depths(count);
	thrust::host_vector<long long> ids(count);
	thrust::host_vector<short> types(count);
	thrust::host_vector<vector<int>> coords(count);

	int cur_depth = 0;
	int cur_width = 0;
	vector<int> cur_coord(depth+1, 0);

	for (int i = 0; i < count; i++) {
		if (cur_width >= width) {
			cur_coord[cur_depth] = 0;
			cur_depth--;
			cur_width = cur_coord[cur_depth];
			i--;
			continue;
		}

		depths[i] = cur_depth;
		types[i] = cur_depth == depth ? 1 : 0;
		cur_coord[cur_depth]++;
		coords[i] = cur_coord;
		cur_width++;

		if (cur_depth < depth) {
			cur_depth++;
			cur_width = 0;
		}
	}

	thrust::sequence(ids.begin(), ids.end());

	cout << "done." << endl;

	if (print) {
		cout << endl << "Before: " << endl;
		print_gpu_tree(depths, ids, types, coords);
		cout << endl;
	}

	cout << "Flattening AST...";

	auto start = chrono::high_resolution_clock::now();
	
	auto end = chrono::high_resolution_clock::now();

	cout << "took " << chrono::duration_cast<chrono::milliseconds>(end - start).count()
		<< " milliseconds." << endl;

	if (print) {
		cout << endl << "After: " << endl;
		print_gpu_tree(depths, ids, types, coords);
	}
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