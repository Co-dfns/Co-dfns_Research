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

struct GPUNode {
	int depth;
	int width;
	long long count;
	thrust::device_vector<int> depths;
	thrust::device_vector<short> types;
	thrust::device_vector<int> coords;
	GPUNode(int depth, int width);
};

GPUNode::GPUNode(int depth, int width)
	: depth(depth), width(width)
{
	count = 0;

	for (int i = 0; i < depth; i++)
		count += (long long)pow(width, i);

	thrust::host_vector<int> host_depths(count);
	thrust::host_vector<short> host_types(count);
	thrust::host_vector<int> host_coords(count * depth, 0);

	int cur_width = 0;
	vector<int> cur_coord(1, 0);

	for (int i = 0; i < count; i++) {
		if (cur_width >= width) {
			cur_coord.pop_back();
			cur_width = cur_coord.back();
			i--;
			continue;
		}

		host_depths[i] = (int)cur_coord.size() - 1;
		host_types[i] = cur_coord.size() >= depth ? 1 : 0;
		cur_coord.back()++;
		for (int j = 0; j < cur_coord.size(); j++)
			host_coords[i*depth + j] = cur_coord[j];
		cur_width++;

		if (cur_coord.size() < depth) {
			cur_width = 0;
			cur_coord.push_back(0);
		}
	}

	depths = host_depths;
	types = host_types;
	coords = host_coords;
}

struct print_gpu_node {
	int max_depth;
	thrust::host_vector<int>& coords;

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
			int c = coords[i*max_depth + j];
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
	thrust::host_vector<int> host_coords = ast.coords;
	thrust::counting_iterator<long long> row(0);

	thrust::for_each(thrust::host,
		thrust::make_zip_iterator(
			thrust::make_tuple(host_depths.begin(), host_types.begin(), row)),
		thrust::make_zip_iterator(
			thrust::make_tuple(host_depths.end(), host_types.end(), row + ast.count)),
		print_gpu_node{ ast.depth, host_coords});
}

typedef thrust::tuple<long long, long long> cpitype;

struct coord_parent_index {
	int max_depth;
	long long exp_count;
	thrust::device_ptr<int> coords;
	thrust::device_ptr<long long> eids;

	coord_parent_index(int md, long long ec, thrust::device_ptr<int> cs, thrust::device_ptr<long long> eids)
		: max_depth(md), exp_count(ec), coords(cs), eids(eids)
	{}

	__host__ __device__
	bool test(const cpitype& t)
	{
		long long ci = thrust::get<0>(t);
		long long ei = thrust::get<1>(t);

		for (int j = 0; j < max_depth - 1; j++) {
			int ref = coords[ei*max_depth + j];
			int cor = coords[ci*max_depth + j];
			int nxt = coords[ci*max_depth + j + 1];

			if (!nxt) {
				if (ref) return false;
				else break;
			}
			if (!ref) break;
			if (ref != cor) return false;
		}

		return true;
	}

	__host__ __device__
	cpitype operator()(const cpitype& t1, const cpitype& t2)
	{
		long long v1 = thrust::get<1>(t1);
		long long v2 = thrust::get<1>(t2);

		if (v1 >= v2) {
			if (test(t1))
				return t1;
			else if (test(t2))
				return t2;
			else
				return thrust::make_tuple<long long, long long>(0, 0);
		}
		else {
			if (test(t2))
				return t2;
			else if (test(t1))
				return t1;
			else
				return thrust::make_tuple<long long, long long>(0, 0);
		}
	}
};

struct copy_coord {
	thrust::device_ptr<int> new_coords;
	thrust::device_ptr<int> old_coords;
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

struct get_ci {
	long long C;

	__host__ __device__
	long long operator()(long long i)
	{
		return 1 + i / C;
	}
};

struct get_ei {
	long long C;
	thrust::device_ptr<long long> eids;

	__host__ __device__
	long long operator()(long long i)
	{
		return eids[i % C];
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
	thrust::device_vector<int> new_coords(result_count * ast.depth);
	thrust::device_vector<long long> refids(result_count);
	thrust::device_vector<long long> keys(result_count);
	thrust::counting_iterator<long long> cids_begin(1);
	thrust::counting_iterator<long long> newids(0);

	thrust::fill(new_depths.begin(), new_depths.begin() + exp_count, 0);
	thrust::fill(new_depths.begin() + exp_count, new_depths.end(), 1);
	thrust::fill(new_types.begin(), new_types.begin() + exp_count, 0);
	thrust::fill(new_types.begin() + exp_count, new_types.end(), 1);

	auto keys_first = keys.begin() + exp_count;

	thrust::copy(eids_begin, eids_end, keys.begin());
	thrust::reduce_by_key(
		thrust::make_transform_iterator(newids, get_ci{ exp_count }),
		thrust::make_transform_iterator(newids + exp_count * (ast.count - 1), get_ci{ exp_count }),
		thrust::make_zip_iterator(thrust::make_tuple(
			thrust::make_transform_iterator(newids, get_ci{ exp_count }),
			thrust::make_transform_iterator(newids, get_ei{ exp_count, eids.data() }))),
		thrust::make_discard_iterator(),
		thrust::make_zip_iterator(thrust::make_tuple(refids.begin(), keys_first)),
		thrust::equal_to<long long>(),
		coord_parent_index(ast.depth, exp_count, ast.coords.data(), eids.data()));
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
	cout << "Benchmarking GPU algorithm (Depth: " << depth << " Width: " << width << ")..." << endl;
	cout << "Creating AST...";

	GPUNode ast(depth+1, width);

	cout << "done." << endl;

	if (print) {
		cout << endl << "Before: " << endl;
		print_gpu_tree(ast);
		cout << endl;
	}

	cout << "Flattening AST...";

	auto start = chrono::high_resolution_clock::now();
	gpu_flatten(ast);
	auto end = chrono::high_resolution_clock::now();

	cout << "took " << chrono::duration_cast<chrono::milliseconds>(end - start).count()
		<< " milliseconds." << endl;

	if (print) {
		cout << endl << "After: " << endl;
		print_gpu_tree(ast);
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