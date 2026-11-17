module Logos
  # Shared by the DSL and enum annotations. Each declaration pairs the
  # token variant with the type stored by its callback.
  macro define_payload_accessors(type, declarations, error_type, existing_methods = [] of String)
    {% accessors = {} of String => String %}
    {% payload_types = {} of String => String %}
    enum {{ type }}
    {% for declaration in declarations %}
      {% variant = declaration[0] %}
      {% payload = declaration[1] %}
      {% accessor = variant.underscore + "_value!" %}
      {% payload_name = payload.stringify %}
      {% if previous_type = payload_types[variant] %}
        {% if previous_type != payload_name %}
          {% payload.raise "Conflicting payload types for #{variant.id}: #{previous_type.id} and #{payload_name.id}" %}
        {% end %}
      {% else %}
        {% if previous_variant = accessors[accessor] %}
          {% payload.raise "Payload accessor #{accessor.id} collides for #{previous_variant.id} and #{variant.id}" %}
        {% end %}
        {% if existing_methods.includes?(accessor) %}
          {% payload.raise "Payload accessor #{accessor.id} collides with an existing method" %}
        {% end %}
        {% accessors[accessor] = variant %}
        {% payload_types[variant] = payload_name %}

        def self.{{ accessor.id }}(result : ::Logos::Result(self, {{ error_type }})) : {{ payload }}
          result.payload_for!({{ variant.id }}, {{ payload }})
        end
      {% end %}
    {% end %}
    end
  end
end
