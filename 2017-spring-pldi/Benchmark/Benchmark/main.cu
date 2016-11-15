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
#include <thrust/iterator/transform_iterator.h>
#include <thrust/remove.h>
#include <thrust/sequence.h>
#include <thrust/inner_product.h>
#include <thrust/functional.h>
#include <thrust/sort.h>
#include <thrust/fill.h>
#include <thrust/execution_policy.h>
#include <thrust/reduce.h>
#include <thrust/tuple.h>
#include <thrust/equal.h>
#include <thrust/transform.h>

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
	cout << "Benchmark <fnc|mut|gpu> <print|quiet> [<depth> <width>|<depth_start> <depth_end> <width_start> <width_end>]" << endl;
}

CPUNode functional_flatten(CPUNode& node)
{
	vector<CPUNode> nodes;

	if (!node.type) {
		vector<CPUNode> kids(node.kids.size());

		for (int i = 0; i < node.kids.size(); i++) {
			kids[i].id = node.kids[i].id;
			kids[i].type = 1;
			kids[i].kids = vector<CPUNode>();
		}

		nodes.push_back(CPUNode(node.id, node.type, kids));

		for (int i = 0; i < node.kids.size(); i++) {
			auto f = functional_flatten(node.kids[i]);
			for (auto k : f.kids) nodes.push_back(k);
		}
	}

	return CPUNode(-1, 0, nodes);
}

void benchmark_functional(int depth, int width, bool print)
{
	cout << "Benchmarking Functional algorithm (Depth: " << depth << " Width: " << width << ")" << endl;
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

	long long timing = 0;

	CPUNode temp;

	for (int i = 0; i < 5; i++) {
		auto start = chrono::high_resolution_clock::now();
		temp = functional_flatten(node);
		auto end = chrono::high_resolution_clock::now();
		timing += chrono::duration_cast<chrono::microseconds>(end - start).count();
	}

	node = temp;

	double average_timing = (double)timing / 5;

	cout << "took an average of " << average_timing / 1000 << " milliseconds." << endl;
	cout << "SET_TIMINGS 0 " << depth << " " << width << " " << average_timing / 1000 << endl;

	if (print) {
		cout << endl << "After: " << endl;
		print_cpu_tree(node, 1);
	}
}

void mutation_flatten_helper(CPUNode& node, vector<CPUNode>& lifted)
{
	if (!node.type) {
		for_each(node.kids.rbegin(), node.kids.rend(), [&lifted](CPUNode& kid) {
			mutation_flatten_helper(kid, lifted);
		});

		lifted.push_back(node);
		node.type = 1;
		node.kids = vector<CPUNode>();
	}
}

void mutation_flatten(CPUNode& node)
{
	vector<CPUNode> lifted;

	mutation_flatten_helper(node, lifted);

	node = CPUNode{ -1, 0, lifted };
}

void benchmark_mutation(int depth, int width, bool print)
{
	cout << "Benchmarking Mutation algorithm (Depth: " << depth << " Width: " << width << ")" << endl;
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

	long long timing = 0;

	CPUNode temp;

	for (int i = 0; i < 5; i++) {
		temp = node;
		auto start = chrono::high_resolution_clock::now();
		mutation_flatten(temp);
		auto end = chrono::high_resolution_clock::now();
		timing += chrono::duration_cast<chrono::microseconds>(end - start).count();
	}

	node = temp;

	double average_timing = (double)timing / 5;

	cout << "took an average of " << average_timing / 1000 << " milliseconds." << endl;
	cout << "SET_TIMINGS 1 " << depth << " " << width << " " << average_timing / 1000 << endl;

	if (print) {
		cout << endl << "After: " << endl;
		print_cpu_tree(node, 1);
	}
}

struct GPUNode {
	int depth;
	int width;
	long long count;
	thrust::device_vector<int> depths;
	thrust::device_vector<short> types;
	thrust::device_vector<long long> coords;
	GPUNode(int depth, int width);
};

GPUNode::GPUNode(int depth, int width)
	: depth(depth), width(width), count(0)
{
	for (int i = 0; i < depth; i++)
		count += (long long)pow(width, i);

	thrust::host_vector<int> host_depths(count);
	thrust::host_vector<short> host_types(count);
	thrust::host_vector<long long> host_coords(count * depth, 0);

	vector<int> cur_width(depth, 0);
	vector<long long> cur_coord(depth, 0);
	int cur_depth = 0;

	for (int i = 0; i < count; i++) {
		if (cur_width[cur_depth] >= width) {
			cur_coord[cur_depth - 1] += cur_coord[cur_depth];
			cur_coord[cur_depth] = 0;
			cur_depth--;
			i--;
			continue;
		}

		host_depths[i] = cur_depth;
		host_types[i] = cur_depth + 1 >= depth ? 1 : 0;
		cur_coord[cur_depth]++;
		cur_width[cur_depth]++;

		host_coords[i*depth + cur_depth] = cur_coord[0];
		for (int j = cur_depth - 1; j >= 0; j--)
			host_coords[i*depth + j] = host_coords[i*depth + j + 1] + cur_coord[cur_depth - j];

		if (cur_depth + 1 < depth) {
			cur_width[++cur_depth] = 0;
		}
	}

	depths = host_depths;
	types = host_types;
	coords = host_coords;
}

struct print_gpu_node {
	int max_depth;
	thrust::host_vector<long long>& coords;

	template <typename Tuple>
	__host__
	void operator()(Tuple t) 
	{
		int depth = thrust::get<0>(t) + 1;

		for (int i = 0; i < depth; i++)
			cout << " ";

		cout << thrust::get<1>(t) << " ";

		long long i = thrust::get<2>(t);

		for (int j = 0; j < max_depth; j++) {
			long long c = coords[i*max_depth + j];
			if (c)
				cout << " " << c;
			else
				break;
		}

		cout << endl;
	}
};

void print_gpu_tree(GPUNode& ast)
{
	thrust::host_vector<int> host_depths = ast.depths;
	thrust::host_vector<short> host_types = ast.types;
	thrust::host_vector<long long> host_coords = ast.coords;
	thrust::counting_iterator<long long> row(0);

	thrust::for_each(thrust::host,
		thrust::make_zip_iterator(
			thrust::make_tuple(host_depths.begin(), host_types.begin(), row)),
		thrust::make_zip_iterator(
			thrust::make_tuple(host_depths.end(), host_types.end(), row + ast.count)),
		print_gpu_node{ ast.depth, host_coords});
}

struct coord_parent_index : public thrust::unary_function<long long, long long> {
	thrust::device_ptr<long long> coords;
	thrust::device_ptr<int> depths;
	thrust::device_ptr<short> types;
	int max_depth;

	coord_parent_index(
		thrust::device_ptr<long long> cs, 
		thrust::device_ptr<int> depths, 
		thrust::device_ptr<short> types, 
		int md)
		: max_depth(md), depths(depths), types(types), coords(cs)
	{}

	__host__ __device__
	long long operator()(long long i) const
	{
		for (int j = 1; j <= depths[i]; j++) {
			auto parent = coords[i * max_depth + j] - 1;
			if (!types[parent])
				return parent;
		}

		return 0;
	}
};

struct copy_coord {
	thrust::device_ptr<long long> new_coords;
	thrust::device_ptr<long long> old_coords;
	int max_depth;

	template <typename Tuple>
	__host__ __device__
	void operator()(Tuple t)
	{
		long long ci = thrust::get<0>(t);
		long long ei = thrust::get<1>(t);
		for (int j = 0; j < max_depth; j++)
			new_coords[ci*max_depth + j] = old_coords[ei*max_depth + j];
	}
};

void gpu_flatten(GPUNode& ast)
{
	thrust::device_vector<long long> eids(ast.count);
	thrust::sequence(eids.begin(), eids.end());

	auto eids_begin = eids.begin();
	auto eids_end = thrust::remove_if(eids_begin, eids.end(), ast.types.begin(), 
		thrust::identity<short>());

	long long exp_count = eids_end - eids_begin;
	long long result_count = ast.count + exp_count - 1;

	thrust::device_vector<int> new_depths(result_count);
	thrust::device_vector<short> new_types(result_count);
	thrust::device_vector<long long> new_coords(result_count * ast.depth);
	thrust::device_vector<long long> refids(result_count);
	thrust::counting_iterator<long long> newids(0);
	thrust::device_vector<long long> keys(result_count);

	thrust::fill(new_depths.begin(), new_depths.begin() + exp_count, 0);
	thrust::fill(new_depths.begin() + exp_count, new_depths.end(), 1);
	thrust::fill(new_types.begin(), new_types.begin() + exp_count, 0);
	thrust::fill(new_types.begin() + exp_count, new_types.end(), 1);

	auto keys_first = keys.begin() + exp_count;

	thrust::copy(eids_begin, eids_end, keys.begin());
	thrust::transform(newids + 1, newids + ast.count, keys_first,
		coord_parent_index(ast.coords.data(), ast.depths.data(), ast.types.data(), ast.depth));
	thrust::copy(eids_begin, eids_end, refids.begin());
	thrust::sequence(refids.begin() + exp_count, refids.end(), 1);
	thrust::stable_sort_by_key(keys.begin(), keys.end(),
		thrust::make_zip_iterator(
			thrust::make_tuple(new_depths.begin(), new_types.begin(), refids.begin())));
	thrust::for_each(
		thrust::make_zip_iterator(thrust::make_tuple(newids, refids.begin())),
		thrust::make_zip_iterator(thrust::make_tuple(newids + result_count, refids.end())),
		copy_coord{ new_coords.data(), ast.coords.data(), ast.depth });

	ast.count = result_count;
	ast.types = new_types;
	ast.coords = new_coords;
	ast.depths = new_depths;
}

void benchmark_gpu(int depth, int width, bool print)
{
	cudaSetDevice(1);

	cout << "Benchmarking GPU algorithm (Depth: " << depth << " Width: " << width << ")..." << endl;
	cout << "Creating AST ";

	GPUNode ast(depth+1, width);

	cout << "done." << endl;

	if (print) {
		cout << endl << "Before: " << endl;
		print_gpu_tree(ast);
		cout << endl;
	}

	cout << "Flattening AST...";

	long long timing = 0;

	GPUNode temp(1, 1);

	for (int i = 0; i < 5; i++) {
		GPUNode temp = ast;
		auto start = chrono::high_resolution_clock::now();
		gpu_flatten(temp);
		auto end = chrono::high_resolution_clock::now();
		timing += chrono::duration_cast<chrono::microseconds>(end - start).count();
	}

	double average_timing = (double)timing / 5;

	cout << "took an average of " << average_timing / 1000 << " milliseconds." << endl;
	cout << "SET_TIMINGS 2 " << depth << " " << width << " " << average_timing / 1000 << endl;

	if (print) {
		gpu_flatten(ast);
		cout << endl << "After: " << endl;
		print_gpu_tree(ast);
	}
}

void print_count(int depth, int width)
{
	long long count = 0;

	for (int i = 0; i <= depth; i++)
		count += (long long)pow(width, i);

	cout << "ASTs should have " << count << " elements." << endl << endl;

}

int main(int argc, char *argv[])
{
	int depth = 3;
	int width = 2;
	int depth_end = 4;
	int width_end = 3;
	bool print = true;

	string print_str("print");
	string quiet_str("quiet");
	string bench_str("bench");
	string fnc_str("fnc");
	string mut_str("mut");
	string gpu_str("gpu");

	if (argc != 3 && argc != 5 && argc != 7) {
		help();
		return 1;
	}

	if (argc == 5) {
		depth = stoi(argv[3]);
		width = stoi(argv[4]);
		depth_end = depth + 1;
		width_end = width + 1;
	}

	if (argc == 7) {
		depth = stoi(argv[3]);
		depth_end = stoi(argv[4]);
		width = stoi(argv[5]);
		width_end = stoi(argv[6]);
	}

	if (print_str == argv[2])
		print = true;
	else if (quiet_str == argv[2])
		print = false;
	else {
		help();
		return 1;
	}

	if (fnc_str == argv[1]) {
		print_count(depth, width);
		for (int i = depth; i < depth_end; i++) {
			for (int j = width; j < width_end; j++) {
				benchmark_functional(i, j, print);
			}
		}
	}
	else if (mut_str == argv[1]) {
		print_count(depth, width);
		for (int i = depth; i < depth_end; i++) {
			for (int j = width; j < width_end; j++) {
				benchmark_mutation(i, j, print);
			}
		}
	}
	else if (gpu_str == argv[1]) {
		print_count(depth, width);
		for (int i = depth; i < depth_end; i++) {
			for (int j = width; j < width_end; j++) {
				benchmark_gpu(i, j, print);
			}
		}
	}
	else if (bench_str == argv[1]) {
		print_count(depth, width);
		for (int i = depth; i < depth_end; i++) {
			for (int j = width; j < width_end; j++) {
				benchmark_functional(i, j, print);
				cout << endl;
				benchmark_mutation(i, j, print);
				cout << endl;
				benchmark_gpu(i, j, print);
			}
		}
	}
	else {
		help();
		return 1;
	}

	return 0;
}