# frozen_string_literal: true

class Clover
  hash_branch(:project_prefix, "kubernetes") do |r|
    r.post true do
      project = @project
      # authorize("Kubernetes:create", project.id)
      # fail Validation::ValidationFailed.new({billing_info: "Project doesn't have valid billing information"}) unless project.has_valid_payment_method?

      params = JSON.parse(json_params)

      st = Prog::Vm::Nexus.assemble_with_sshable(
        params["unix_user"],
        project.id,
        location: "hetzner-fsn1",
        name: params["name"],
        private_subnet_id: params["private_subnet_id"],
        size: "standard-2",
        storage_volumes: [
          {encrypted: true, size_gib: 30}
        ],
        boot_image: "ubuntu-jammy",
        enable_ip4: true
      )

      Serializers::Vm.serialize(st.subject, {detailed: true})
    end

    r.post "run-cmd" do
      params = JSON.parse(json_params)
      cmd = params["cmd"]
      vm = Vm[params["vm_ubid"]]
      res = vm.sshable.cmd cmd

      {result: res}.to_json
    end
  end
end
