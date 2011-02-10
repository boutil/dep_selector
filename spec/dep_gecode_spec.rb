require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'ext/gecode/dep_gecode'

simple_cookbook_version_constraint =
  [{"key"=>["A", "1.0.0"], "value"=>{"B"=>"= 2.0.0"}},
   {"key"=>["A", "2.0.0"], "value"=>{"B"=>"= 1.0.0", "C"=>"= 1.0.0"}},
   {"key"=>["B", "1.0.0"], "value"=>{}},
   {"key"=>["B", "2.0.0"], "value"=>{}},
   {"key"=>["C", "1.0.0"], "value"=>{}}
  ]

# so that we can use test data that's already written in other tests,
# we're accepting the same format but adapting it for our C++ wrapper
# for gecode, which is exposed in Dep_gecode
def setup_problem_for_dep_gecode(relationships)
  dep_graph = DepSelector::DependencyGraph.new
  setup_constraint(dep_graph, relationships)

  dep_gecode_packages = {}
  problem = Dep_gecode.VersionProblemCreate(dep_graph.packages.size+1) # extra for runlist meta package

  # all packages must be created before dependencies using them can be created
  dep_graph.each_package do |package|
    versions = package.densely_packed_versions.range
    dep_gecode_packages[package.name] = Dep_gecode.AddPackage(problem, versions.min, versions.max, versions.max)
  end

  # register dependencies of each package version
  dep_graph.each_package do |package|
    pkg_id = dep_gecode_packages[package.name]
    package.versions.each do |pkg_ver|
      pkg_ver_id = package.densely_packed_versions.index(pkg_ver.version)
      pkg_ver.dependencies.each do |dep|
        matching_ver_ids = dep.package.densely_packed_versions[dep.constraint]
        Dep_gecode.AddVersionConstraint(problem,
                                        pkg_id,
                                        pkg_ver_id,
                                        dep_gecode_packages[dep.package.name],
                                        matching_ver_ids.min,
                                        matching_ver_ids.max)
      end
    end
  end

  [ problem, dep_graph, dep_gecode_packages ]
end

def setup_soln_constraints_for_dep_gecode(soln_constraints, problem, pkg_name_to_id, dep_graph)
  # metapackage is a "ghost" package whose dependencies are the
  # solution constraints; thereby forcing packages to be appropriately
  # constrained
  metapkg = Dep_gecode.AddPackage(problem, 0, 0, 0)

  # we go through the expense of calling setup_soln_constraints,
  # because ultimately we're after the densely-packed ids of each
  # package and constraint, which we get for free by using the
  # dep_graph.
  setup_soln_constraints(dep_graph, soln_constraints).each do |soln_constraint|
    matching_ver_ids = soln_constraint.package.densely_packed_versions[soln_constraint.constraint]
    Dep_gecode.AddVersionConstraint(problem,
                                    metapkg,
                                    0,
                                    pkg_name_to_id[soln_constraint.package.name],
                                    matching_ver_ids.min,
                                    matching_ver_ids.max)
  end
end


def print_bindings(problem, vars)
  vars.each do |var|
    Dep_gecode.VersionProblemPrintPackageVar(problem, var)
    puts "\n"
  end
end

describe Dep_gecode do

  before do
    @problem, @dep_graph, @pkg_name_to_id = setup_problem_for_dep_gecode(simple_cookbook_version_constraint)
  end

  it "solves a simple set of constraints" do
    puts "before adding soln constraints"
    print_bindings(@problem, [*(0..2)])

    # solution constraints: [A,(B=0)], which is satisfiable as A=1, B=0
    solution_constraints = [
                            ["A"],
                            ["B", "= 1.0.0"]
                           ]
    setup_soln_constraints_for_dep_gecode(solution_constraints, @problem, @pkg_name_to_id, @dep_graph)

    puts "after adding soln constraints"
    print_bindings(@problem, [*(0..3)])

    # solve and interrogate problem
    puts "Solving"
    new_problem = Dep_gecode.Solve(@problem)
    puts "Solved"

    puts "after solving"
    print_bindings(new_problem, [*(0..3)])

    # TODO: check problem's bindings
  end

  it "fails to solve a simple, unsatisfiable set of constraints" do
    puts "before adding soln constraints"
    print_bindings(@problem, [*(0..2)])

    # solution constraints: [(A=1.0.0),(B=1.0.0)], which is not satisfiable
    solution_constraints = [
                            ["A", "= 1.0.0"],
                            ["B", "= 1.0.0"]
                           ]
    setup_soln_constraints_for_dep_gecode(solution_constraints, @problem, @pkg_name_to_id, @dep_graph)

    puts "after adding soln constraints"
    print_bindings(@problem, [*(0..3)])

    # solve and interrogate problem
    puts "Solving"
    new_problem = Dep_gecode.Solve(@problem)

    new_problem.should == nil

    puts "after solving"
    if (!new_problem.nil?)
      print_bindings(new_problem, [*(0..3)])
    else
      puts "No solution"
    end
    


    # TODO: do appropriate interrogation
  end

end
