# frozen_string_literal: true

require "json"

class Prog::DownloadBootImage < Prog::Base
  subject_is :sshable, :vm_host

  def image_name
    @image_name ||= frame.fetch("image_name")
  end

  def version
    @version ||= frame.fetch("version") { default_boot_image_version(image_name) }
  end

  def download_from_blob_storage?
    image_name.start_with?("github", "postgres", "ai-") || Config.production?
  end

  def default_boot_image_version(image_name)
    config_name = image_name.tr("-", "_") + "_version"
    fail "Unknown boot image: #{image_name}" unless Config.respond_to?(config_name)
    Config.send(config_name)
  end

  def url
    @url ||=
      if frame["custom_url"]
        frame["custom_url"]
      elsif download_from_blob_storage?
        suffixes = {
          "github" => "raw",
          "postgres16" => "raw",
          "postgres17" => "raw",
          "ubuntu" => "img",
          "almalinux" => "qcow2",
          "debian" => "raw",
          "ai" => "raw"
        }
        image_family = image_name.split("-").first
        suffix = suffixes.fetch(image_family, nil)
        arch = image_name.start_with?("ai-model") ? "-" : "-#{vm_host.arch}-"
        blob_storage_client.get_presigned_url("GET", Config.ubicloud_images_bucket_name, "#{image_name}#{arch}#{version}.#{suffix}", 60 * 60).to_s
      elsif image_name == "ubuntu-noble"
        arch = vm_host.render_arch(arm64: "arm64", x64: "amd64")
        "https://cloud-images.ubuntu.com/releases/noble/release-#{version}/ubuntu-24.04-server-cloudimg-#{arch}.img"
      elsif image_name == "ubuntu-jammy"
        arch = vm_host.render_arch(arm64: "arm64", x64: "amd64")
        "https://cloud-images.ubuntu.com/releases/jammy/release-#{version}/ubuntu-22.04-server-cloudimg-#{arch}.img"
      elsif image_name == "debian-12"
        arch = vm_host.render_arch(arm64: "arm64", x64: "amd64")
        "https://cloud.debian.org/images/cloud/bookworm/#{version}/debian-12-genericcloud-#{arch}-#{version}.raw"
      elsif image_name == "almalinux-9"
        arch = vm_host.render_arch(arm64: "aarch64", x64: "x86_64")
        "https://repo.almalinux.org/almalinux/9/cloud/#{arch}/images/AlmaLinux-9-GenericCloud-#{version}.#{arch}.qcow2"
      else
        fail "Unknown image name: #{image_name}"
      end
  end

  def sha256_sum
    hashes = {
      ["ubuntu-noble", "x64", "20240523.1"] => "b60205f4cc48a24b999ad0bd61ceb9fe28abfe4ac3701acb7bb5d6b0b5fdc624",
      ["ubuntu-noble", "arm64", "20240523.1"] => "54f6b62cc8d393e5c82495a49b8980157dfa6a13b930d8d4170e34e30742d949",
      ["ubuntu-noble", "x64", "20240702"] => "182dc760bfca26c45fb4e4668049ecd4d0ecdd6171b3bae81d0135e8f1e9d93e",
      ["ubuntu-noble", "arm64", "20240702"] => "5fe06e10a3b53cfff06edcb8595552b1f0372265b69fa424aa464eb4bcba3b09",
      ["ubuntu-jammy", "x64", "20240319"] => "304983616fcba6ee1452e9f38993d7d3b8a90e1eb65fb0054d672ce23294d812",
      ["ubuntu-jammy", "arm64", "20240319"] => "40ea1181447b9395fa03f6f2c405482fe532a348cc46fbb876effcfbbb35336f",
      ["ubuntu-jammy", "x64", "20240701"] => "769f0355acc3f411251aeb96401a827248aae838b91c637d991ea51bed30eeeb",
      ["ubuntu-jammy", "arm64", "20240701"] => "76423945c97fddd415fa17610c7472b07c46d6758d42f4f706f1bbe972f51155",
      ["debian-12", "arm64", "20241004-1890"] => "7965a9b9f02eb473138e6357def557029053178e4cd37c19e620f674ca7224c0",
      ["debian-12", "x64", "20241004-1890"] => "5af3d0e134eb3560ab035021763401d1ec72a25c761fe0ce964351e1409c523d",
      ["almalinux-9", "x64", "9.5-20241120"] => "abddf01589d46c841f718cec239392924a03b34c4fe84929af5d543c50e37e37",
      ["almalinux-9", "arm64", "9.5-20241120"] => "5ede4affaad0a997a2b642f1628b6268bd8eba775f281346b75be3ed20ec369e",
      ["github-ubuntu-2404", "x64", "20241016.1.0"] => "c0b2f8bb88c6f8a5e30903ce6052a98294d10dda4aa0f29111862bdfb98038d8",
      ["github-ubuntu-2404", "x64", "20241124.1.1"] => "b6119c25ef1407ac1ebbb6ccb8fd87a73bce9450c573ff6ca5ff9429552e2595",
      ["github-ubuntu-2404", "arm64", "20241016.1.0"] => "6319e8385350f9391b7cbf5b78497ce6486be40c1d3e4201a6af8383152cb68e",
      ["github-ubuntu-2404", "arm64", "20241124.1.1"] => "4b797648ffb5b8bf07d4019d38ea2417ed2965787360a7c7f8c4095f071b09c5",
      ["github-ubuntu-2204", "x64", "20241016.1.0"] => "bf6d35e64444e7871881435b322b23071d3a7b07f52aae3c27d5c3cea0618429",
      ["github-ubuntu-2204", "x64", "20241124.1.1"] => "6203e117a6013250b9ee28a884444a702589d3b2bcd16e711536881f4b9eb3f0",
      ["github-ubuntu-2204", "arm64", "20241016.1.0"] => "a1d1fc3a1ab69fcc4845b0d049e8d7151762b0108ddcc0be7694eb93c807e941",
      ["github-ubuntu-2204", "arm64", "20241124.1.1"] => "b0126228ba0f5aef0b465faece2df1c0dc36211306221c9dcdf35e6cc720eec2",
      ["github-ubuntu-2004", "x64", "20241016.1.0"] => "643d5faec985e0224a7ec26eee5bf8d512fef85c095838e5b4654137992a1a25",
      ["github-ubuntu-2004", "x64", "20241124.1.1"] => "23757d95d41be14f8b70312a1037c651f768819957dcdf75ddf1bc75b779d4ef",
      ["github-ubuntu-2004", "arm64", "20241016.1.0"] => "ff853e4a272f2e0b27c1f119ea39b027da52221965c4161d02493c7bccb0c6fc",
      ["github-ubuntu-2004", "arm64", "20241124.1.1"] => "cd31efb3a0bf40963eb4851c6cba81852a1c53c73c1221b13bc77656f668045c",
      ["github-gpu-ubuntu-2204", "x64", "20241016.1.0"] => "48e43b492d562a639a65fb66577e901da073b76451eab1cb65d720b37715fffa",
      ["github-gpu-ubuntu-2204", "x64", "20241124.1.1"] => "9414296a3d52ff9b86c0727c23e088c2213db3c77ac2bf7a0eec9def47391548",
      ["postgres16-ubuntu-2204", "x64", "20241022.1.0"] => "9e719cebae7f9700bf1d80855fd12f4cf9ea75cd82887fab9b2ee7ab4a292d25",
      ["postgres17-ubuntu-2204", "x64", "20241022.1.0"] => "ad2c1dd2029bd9ffaff105ca231d820d59b318a9b32c0155d8d5baa13343e6fa",
      ["postgres16-paradedb-ubuntu-2204", "x64", "20241022.1.0"] => "1256a2e13f059f08747df6a0b2125ecbc756aa34666d7d1d5c86b32f8fe4b4d0",
      ["postgres17-paradedb-ubuntu-2204", "x64", "20241022.1.0"] => "d510cbc817114d424266cfca37deb011ae31b071c52f2013f98af17f6c0b032f",
      ["postgres16-lantern-ubuntu-2204", "x64", "20241010.1.0"] => "608766a3dc4be757c32c2855893ebaf5d92a55675205cd4c9aec1b0a8bc274fb",
      ["ai-ubuntu-2404-nvidia", "x64", "20250108.1.0"] => "ad87578811c0964482099b84d8e2e391554e4d05fc204f8a15374df1978abbd9",
      ["ai-model-gemma-2-2b-it", "x64", "20240918.1.0"] => "b726ead6d5f48fb8e6de7efb48fb22367c9a7c155cfee71a3a7e5527be5df08e",
      ["ai-model-llama-3-1-405b-it", "x64", "20241029.1.0"] => "54680b8b18ed501956a78c63b94576b7200fbd8fbe025eccb90152d13478882e",
      ["ai-model-llama-3-2-3b-it", "x64", "20241028.1.0"] => "023d2a285564f3b75413c537b1242e4c2acfea3d3f88912c595da80354516fba",
      ["ai-model-llama-guard-3-1b", "x64", "20241028.1.0"] => "ef85abe990d26ded8e231fd05195c580b517b6555fe8f1dc9463012ce3e93f3f",
      ["ai-model-llama-guard-3-8b", "x64", "20241028.1.0"] => "7f856f564626214a57f4788489b9e588ea63a537bd88aadb14e4745aab219c5c",
      ["ai-model-e5-mistral-7b-it", "x64", "20241016.1.0"] => "999b0ff41968ffede0408ce3d4a9a21ff23e391f7aeac2f2d492fd505e73826c",
      ["ai-model-llama-3-3-70b-it", "x64", "20241209.1.0"] => "b5a77810de7f01df5b76b6362fc5b4514cc16c6926ee203ecc8643233c6d2704",
      ["ai-model-qwq-32b-preview", "x64", "20241209.1.0"] => "38ca4912134ed9b115726eff258666d68ce6df92330a3585d47494099821f9b1"
    }

    # YYY: In future all images should be checked for sha256 sum, so the nil
    # default will be removed.
    hashes.fetch([image_name, vm_host.arch, version], nil)
  end

  def blob_storage_client
    @blob_storage_client ||= Minio::Client.new(
      endpoint: Config.ubicloud_images_blob_storage_endpoint,
      access_key: Config.ubicloud_images_blob_storage_access_key,
      secret_key: Config.ubicloud_images_blob_storage_secret_key,
      ssl_ca_file_data: Config.ubicloud_images_blob_storage_certs
    )
  end

  label def start
    # YYY: we can remove this once we enforce it in the database layer.
    # Although the default version is used if version is not passed, adding
    # a sanity check here to make sure version is not passed as nil.
    fail "Version can not be passed as nil" if version.nil?

    fail "Image already exists on host" if vm_host.boot_images_dataset.where(name: image_name, version: version).count > 0

    BootImage.create_with_id(
      vm_host_id: vm_host.id,
      name: image_name,
      version: version,
      activated_at: nil,
      size_gib: 0
    )
    hop_download
  end

  label def download
    q_daemon_name = "download_#{image_name}_#{version}".shellescape
    case sshable.cmd("common/bin/daemonizer --check #{q_daemon_name}")
    when "Succeeded"
      sshable.cmd("common/bin/daemonizer --clean #{q_daemon_name}")
      hop_update_available_storage_space
    when "NotStarted"
      params_json = {
        image_name: image_name,
        url: url,
        version: version,
        sha256sum: sha256_sum,
        certs: download_from_blob_storage? ? Config.ubicloud_images_blob_storage_certs : nil
      }.to_json
      sshable.cmd("common/bin/daemonizer 'host/bin/download-boot-image' #{q_daemon_name}", stdin: params_json)
    when "Failed"
      if Config.production?
        BootImage.where(vm_host_id: vm_host.id, name: image_name, version: version).destroy
      else
        sshable.cmd("common/bin/daemonizer --clean #{q_daemon_name}")
      end
      fail "Failed to download '#{image_name}' image on #{vm_host}"
    end

    nap 15
  end

  label def update_available_storage_space
    image = BootImage[vm_host_id: vm_host.id, name: image_name, version: version]
    image_size_bytes = sshable.cmd("stat -c %s #{image.path.shellescape}").to_i
    image_size_gib = (image_size_bytes / 1024.0**3).ceil
    StorageDevice.where(vm_host_id: vm_host.id, name: "DEFAULT").update(
      available_storage_gib: Sequel[:available_storage_gib] - image_size_gib
    )
    image.update(size_gib: image_size_gib)
    hop_activate_boot_image
  end

  label def activate_boot_image
    BootImage.where(
      vm_host_id: vm_host.id,
      name: image_name,
      version: version
    ).update(activated_at: Time.now)
    pop({"msg" => "image downloaded", "name" => image_name, "version" => version})
  end
end
