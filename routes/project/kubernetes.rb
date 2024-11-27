# frozen_string_literal: true

class Clover
  hash_branch(:project_prefix, "kubernetes-internal") do |r|
    r.post true do
      project = @project

      puts project.id
      # authorize("Kubernetes:create", project.id)
      # fail Validation::ValidationFailed.new({billing_info: "Project doesn't have valid billing information"}) unless project.has_valid_payment_method?

      st = Prog::Vm::Nexus.assemble_with_sshable(
        "ubi",
        project.id,
        location: "hetzner-fsn1",
        name: json_params["name"],
        size: "standard-2",
        storage_volumes: [
          {encrypted: true, size_gib: 30}
        ],
        boot_image: "ubuntu-jammy",
        enable_ip4: true
      )

      Serializers::Vm.serialize(st.subject, {detailed: true})
    end
  end
end
