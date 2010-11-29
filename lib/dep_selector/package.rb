require 'dep_selector/package_version'
require 'dep_selector/densely_packed_set'

module DepSelector
  class Package
    attr_reader :dependency_graph, :name, :versions

    def initialize(dependency_graph, name)
      @dependency_graph = dependency_graph
      @name = name
      @versions = []
    end

    def add_version(version)
      versions << (pv = PackageVersion.new(self, version))
      pv
    end

    # Note: only invoke this method after all PackageVersions have been added
    def densely_packed_versions
      @densely_packed_versions ||= DenselyPackedSet.new(versions.map{|pkg_version| pkg_version.version})
    end

    # Note: Since this invokes densely_packed_versions, only invoke
    # this method after all PackageVersions have been added
    def version_str_from_densely_packed_version(dpv)
      densely_packed_versions.sorted_triples[dpv]
    end

    def version_by_str(version_str)
      versions.find{|pkg_version| pkg_version.version == version_str}
    end

    def to_s
      "Package #{name}\n  #{versions.map{|v|v.to_s}.join("\n  ")}"
    end

    # Note: only invoke this method after all PackageVersions have been added
    def gecode_model_var
      @gecode_model_var ||= dependency_graph.int_var(densely_packed_versions.range)
    end

    def generate_gecode_constraints
      versions.each{|version| version.generate_gecode_constraints }
    end
  end
end
